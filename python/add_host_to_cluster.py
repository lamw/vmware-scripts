#!/usr/bin/env python
# Pyvmomi (vSphere SDK for Python) script for adding ESXi host to vSphere Cluster connected to vCenter Server, which can run directly on ESXi host
# Credit goes to ChatGPT for creating nthe script based on my requirements :)
#
# Example:
#   python add_host_to_cluster.py \
#     --vcenter vc03.williamlam.local --vc-user 'administrator@vsphere.local' --vc-pass 'VMware1!' \
#     --datacenter 'Datacenter' --cluster 'Cluster-01' \
#     --host-user 'root' --host-pass 'VMware1!' --insecure --vmk vmk0
#

import argparse, atexit, hashlib, json, os, re, socket, ssl, subprocess, time, ipaddress
from pyVim import connect
from pyVmomi import vim

ESXCLI = "/usr/sbin/esxcli"

def run(cmd):
    return subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)

def is_valid_ipv4(s):
    try:
        ip = ipaddress.IPv4Address(s)
        # reject obvious masks/bad placeholders
        if s in {"0.0.0.0", "255.255.255.255"}:
            return False
        return True
    except Exception:
        return False

def parse_esxcli_csv_for_ip(text, vmk):
    # Expect header line then values. Normalize header names.
    lines = [l for l in text.splitlines() if l.strip()]
    if not lines:
        return None
    headers = [h.strip().lower().replace(" ", "") for h in lines[0].split(",")]
    # Common header names: name,ipv4address,address,netmask,broadcast,dhcp,mtu,...
    try:
        name_idx = headers.index("name")
    except ValueError:
        return None
    # Prefer a precise IPv4 address column
    for cand in ("ipv4address", "address"):
        if cand in headers:
            addr_idx = headers.index(cand)
            break
    else:
        return None

    for line in lines[1:]:
        cols = [c.strip() for c in line.split(",")]
        if len(cols) <= max(name_idx, addr_idx):
            continue
        if cols[name_idx] == vmk and is_valid_ipv4(cols[addr_idx]):
            return cols[addr_idx]
    return None

def parse_esxcli_text_for_ip(text, vmk):
    """
    Parse plain text table from:
      esxcli network ip interface ipv4 get -i <vmk>
    ESXi varies, but usually shows key:value lines for single interface.
    """
    # Look for a line like 'IPv4 Address: 192.168.30.4'
    for line in text.splitlines():
        if "IPv4 Address" in line:
            m = re.search(r"IPv4 Address\s*:\s*([0-9.]+)", line)
            if m and is_valid_ipv4(m.group(1)):
                return m.group(1)
    # Fallback older tabular formats:
    # Try to find a line that starts with vmk and pick the token after it if it looks like IPv4
    for line in text.splitlines():
        if line.strip().startswith(vmk):
            parts = line.split()
            # scan each token for IPv4
            for tok in parts:
                if re.match(r"^\d{1,3}(\.\d{1,3}){3}$", tok) and is_valid_ipv4(tok):
                    return tok
    return None

def parse_esxcfg_vmknic_for_ip(text, vmk):
    # Example: "vmk0 ... IPv4: 192.168.30.4  Netmask: 255.255.255.0 ..."
    # Use a regex that anchors on the interface name and the "IPv4:" label specifically.
    pattern = rf"^{re.escape(vmk)}.*?IPv4:\s*([0-9.]+)\b"
    for line in text.splitlines():
        m = re.search(pattern, line)
        if m and is_valid_ipv4(m.group(1)):
            return m.group(1)
    return None

def get_vmk_ip(vmk="vmk0", vcenter_hint=None):
    # 1) esxcli CSV
    for csv_flag in ("--formatter=csv", "--format=csv"):
        try:
            out = run([ESXCLI, csv_flag, "network", "ip", "interface", "ipv4", "get", "-i", vmk])
            ip = parse_esxcli_csv_for_ip(out, vmk)
            if ip:
                return ip
        except Exception:
            pass

    # 2) esxcli JSON
    for json_flag in ("--formatter=json", "--format=json"):
        try:
            out = run([ESXCLI, json_flag, "network", "ip", "interface", "ipv4", "get", "-i", vmk])
            data = json.loads(out)
            items = None
            if isinstance(data, dict):
                for key in ("ip", "Interfaces", "vmknics", "Items", "items"):
                    if key in data and isinstance(data[key], list):
                        items = data[key]
                        break
            elif isinstance(data, list):
                items = data
            if items:
                for it in items:
                    name = it.get("Name") or it.get("name") or it.get("Interface")
                    addr = it.get("IPv4Address") or it.get("Address") or it.get("address")
                    if name == vmk and addr and is_valid_ipv4(addr):
                        return addr
        except Exception:
            pass

    # 3) esxcli text (single interface)
    try:
        out = run([ESXCLI, "network", "ip", "interface", "ipv4", "get", "-i", vmk])
        ip = parse_esxcli_text_for_ip(out, vmk)
        if ip:
            return ip
    except Exception:
        pass

    # 4) esxcfg-vmknic -l
    try:
        out = run(["/sbin/esxcfg-vmknic", "-l"])
        ip = parse_esxcfg_vmknic_for_ip(out, vmk)
        if ip:
            return ip
    except Exception:
        pass

    # 5) UDP socket trick using vCenter hint, last-resort
    try:
        target = (vcenter_hint or "8.8.8.8", 443)
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(target)
        ip = s.getsockname()[0]
        s.close()
        if is_valid_ipv4(ip):
            return ip
    except Exception:
        pass

    raise RuntimeError(f"Unable to determine IPv4 for {vmk}. Try --host <IP> or --vmk <vmkN>.")

def get_ssl_thumbprint(host, port=443, timeout=5):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    with socket.create_connection((host, port), timeout=timeout) as sock:
        with ctx.wrap_socket(sock, server_hostname=host) as ssock:
            der = ssock.getpeercert(binary_form=True)
    fp = hashlib.sha1(der).hexdigest().upper()
    return ":".join(fp[i:i+2] for i in range(0, len(fp), 2))

def find_obj_by_name(content, vimtype, name):
    view = content.viewManager.CreateContainerView(content.rootFolder, [vimtype], True)
    try:
        for obj in view.view:
            if obj.name == name:
                return obj
    finally:
        view.Destroy()
    return None

def wait_for_task(task, action_name='task'):
    while True:
        st = task.info.state
        if st == 'success':
            return task.info.result
        if st == 'error':
            msg = task.info.error.msg if task.info.error else 'unknown error'
            raise RuntimeError(f"{action_name} failed: {msg}")
        time.sleep(1)

def main():
    ap = argparse.ArgumentParser(description="Add the (local) ESXi host to a vSphere Cluster via pyVmomi")
    ap.add_argument("--vcenter", required=True)
    ap.add_argument("--vc-user", required=True)
    ap.add_argument("--vc-pass", required=True)
    ap.add_argument("--datacenter", required=True)
    ap.add_argument("--cluster", required=True)
    ap.add_argument("--host", default="", help="ESXi host IP/FQDN to add (omit to auto-detect)")
    ap.add_argument("--vmk", default="vmk0", help="VMkernel to read IP from when auto-detecting (default: vmk0)")
    ap.add_argument("--host-user", default="root")
    ap.add_argument("--host-pass", required=True)
    ap.add_argument("--license", default="")
    ap.add_argument("--insecure", action="store_true")
    args = ap.parse_args()

    # Determine host IP to add
    if args.host.strip():
        host_to_add = args.host.strip()
    else:
        host_to_add = get_vmk_ip(args.vmk, vcenter_hint=args.vcenter)
    print(f"[i] Using ESXi host: {host_to_add}")

    # vCenter connection
    if args.insecure:
        ctx = ssl._create_unverified_context()
        si = connect.SmartConnect(host=args.vcenter, user=args.vc_user, pwd=args.vc_pass, sslContext=ctx)
    else:
        si = connect.SmartConnect(host=args.vcenter, user=args.vc_user, pwd=args.vc_pass)
    atexit.register(connect.Disconnect, si)
    content = si.RetrieveContent()

    # Inventory lookup
    dc = find_obj_by_name(content, vim.Datacenter, args.datacenter)
    if not dc:
        raise SystemExit(f"Datacenter not found: {args.datacenter}")
    cluster = find_obj_by_name(content, vim.ClusterComputeResource, args.cluster)
    if not cluster:
        raise SystemExit(f"Cluster not found: {args.cluster}")

    # Thumbprint + add
    print("[i] Fetching ESXi SSL thumbprint…")
    thumb = get_ssl_thumbprint(host_to_add)
    print(f"[i] Thumbprint: {thumb}")

    spec = vim.host.ConnectSpec(
        hostName=host_to_add,
        userName=args.host_user,
        password=args.host_pass,
        sslThumbprint=thumb,
        force=True,
    )

    print(f"[i] Adding host {host_to_add} to cluster '{args.cluster}'…")
    task = cluster.AddHost_Task(spec=spec, asConnected=True, resourcePool=cluster.resourcePool,
                               license=(args.license or None))
    wait_for_task(task, action_name="AddHost_Task")
    print(f"✅ Host {host_to_add} added to cluster '{args.cluster}' in datacenter '{args.datacenter}'")

if __name__ == "__main__":
    main()

