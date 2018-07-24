"""
Generates a library ready to be used as a VCSP endpoint for content library 2016 (vsphere 6.5).
"""

__author__ = 'VMware, Inc.'
__copyright__ = 'Copyright VMware, Inc. All rights reserved.'

import argparse
import boto3
import hashlib
import logging
import json
import os
import uuid
import sys

from botocore.client import ClientError
from datetime import datetime

VCSP_VERSION = 2
ISO_FORMAT = "%Y-%m-%dT%H:%MZ"
FORMAT = "json"
LIB_FILE = ''.join(("lib", os.extsep, FORMAT))
ITEMS_FILE = ''.join(("items", os.extsep, FORMAT))
ITEM_FILE = ''.join(("item", os.extsep, FORMAT))
VCSP_TYPE_OVF = "vcsp.ovf"
VCSP_TYPE_ISO = "vcsp.iso"
VCSP_TYPE_OTHER = "vcsp.other"

logger = logging.getLogger(__name__)

def _md5_for_file(f, md5=None, block_size=2**20):
    if md5 is None:
        md5 = hashlib.md5()
    while True:
        data = f.read(block_size)
        if not data:
            break
        md5.update(data)
    return md5


def _md5_for_folder(folder):
    md5 = None
    for files in os.listdir(folder):
        if ITEM_FILE not in files:
            with open(os.path.join(folder, files), "rb") as handle:
                md5 = _md5_for_file(handle, md5)
    return md5.hexdigest()


def _make_lib(name, id=uuid.uuid4(), creation=datetime.now(), version=1):
    return {
            "vcspVersion": str(VCSP_VERSION),
            "version": str(version),
            "contentVersion": "1",
            "name": name,
            "id": "urn:uuid:%s" % id,
            "created": creation.strftime(ISO_FORMAT),
            "capabilities": {
            "transferIn": [ "httpGet" ],
            "transferOut": [ "httpGet" ],
            },
        "itemsHref": ITEMS_FILE
    }


def _make_item(directory, vcsp_type, name, files, description="", properties={},
               identifier=uuid.uuid4(), creation=datetime.now(), version=2):
    return {
        "created": creation.strftime(ISO_FORMAT),
        "description": description,
        "version": str(version),
        "files": files,
        "id": "urn:uuid:%s" % identifier,
        "name": name,
        "properties": properties,
        "selfHref": "%s/%s" % (directory, ITEM_FILE),
        "type": vcsp_type
    }


def _make_items(items, version=1):
    return {
        "items": items
    }


def _dir2item(path, directory, md5_enabled):
    files_items = []
    name = os.path.split(path)[-1]
    vcsp_type = VCSP_TYPE_OTHER
    folder = ""
    folder_md5 = ""
    for f in os.listdir(path):
        if f == ".DS_Store" or f == ''.join((directory, os.extsep, FORMAT)):
            continue
        else:
            if f == "item.json":
                continue # skip the item.json meta data files
            p = os.path.join(path, f)
            m = hashlib.md5()
            new_folder = os.path.dirname(p)
            if new_folder != folder: # new folder (ex: template1/)
                if md5_enabled:
                    folder_md5 = _md5_for_folder(new_folder)
                folder = new_folder
            if md5_enabled:
                m.update(os.path.dirname(p).encode('utf-8'))
            if ".ovf" in p:
                vcsp_type = VCSP_TYPE_OVF
            elif ".iso" in p:
                vcsp_type = VCSP_TYPE_ISO
            size = os.path.getsize(p)
            href = "%s/%s" % (directory, f)
            h = ""
            if md5_enabled:
                with open(p, "rb") as handle:
                    h = _md5_for_file(handle)
            files_items.append({
                "name": f,
                "size": size,
                "etag": folder_md5,
                "hrefs": [ href ]
            })
    return _make_item(name, vcsp_type, name, files_items, identifier = uuid.uuid4())


def _dir2item_s3(s3_client, bucket_name, path, item_name):
    """
    Generate items jsons for the given item path on s3

    if the folder only contains iso files, then one item will be created for each
    iso file, and its item json will be generated accordingly; otherwise only one
    item json will be generated.

    Args:
        s3_client: S3 client
        bucket_name: S3 bucket name
        path: item path on S3 bucket
        item_name: name of the item

    Returns:
        map of item name to item json
    """
    items_jsons = {}
    files_items = []
    vcsp_type = None
    response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=path, Delimiter="/")

    for content in response['Contents']:
        file_path = content['Key']
        if file_path == path or file_path.endswith("item.json"):
            continue
        file_name = file_path.split("/")[-1]
        if ".ovf" in file_name:
            vcsp_type = VCSP_TYPE_OVF
        if vcsp_type != VCSP_TYPE_OVF and ".iso" not in file_name:
            vcsp_type = VCSP_TYPE_OTHER
        if vcsp_type not in [VCSP_TYPE_OVF, VCSP_TYPE_OTHER] and ".iso" in file_name:
            vcsp_type = VCSP_TYPE_ISO  # only if all files are iso, then it is ISO type

    for content in response['Contents']:
        file_path = content['Key']
        file_name = file_path.split("/")[-1]
        href = "%s/%s" % (item_name, file_name)

        if  file_path == path or file_path.endswith("item.json"):
            continue # skip the item folder and item.json meta data file

        size = content['Size']
        file_json = {
            "name": file_name,
            "size": size,
            "etag": content['ETag'].strip('"'),
            "hrefs": [ href ]
        }

        if vcsp_type == VCSP_TYPE_ISO:
            extension_index = file_name.rfind('.')
            child_item_name = file_name[:extension_index]
            # note: it is not necessary to create a child iso item folder if not exist
            item_path = item_name + "/" + child_item_name
            items_jsons[child_item_name] = _make_item(item_path, vcsp_type, child_item_name, [file_json], identifier = uuid.uuid4())
        else:
            files_items.append(file_json)
    
    if vcsp_type != VCSP_TYPE_ISO:
        items_jsons[item_name] = _make_item(item_name, vcsp_type, item_name, files_items, identifier = uuid.uuid4())

    return items_jsons


def make_vcsp(lib_name, lib_path, md5_enabled):
    lib_json_loc = os.path.join(lib_path, LIB_FILE)
    lib_items_json_loc = os.path.join(lib_path, ITEMS_FILE)

    lib_id = uuid.uuid4()
    lib_create = datetime.now()
    lib_version = 1
    updating_lib = False
    if os.path.isfile(lib_json_loc):
        logger.info("%s already exists (%s)" % (LIB_FILE, lib_json_loc))
        try:
            with open(lib_json_loc, "r") as f:
                old_lib = json.load(f)
            if "id" in old_lib:
                lib_id = old_lib["id"].split(":")[-1]
            if "created" in old_lib:
                lib_create = datetime.strptime(old_lib["created"], ISO_FORMAT)
            if "version" in old_lib:
                lib_version = old_lib["version"]
                updating_lib = True
        except:
            logger.error("Failed to read %s" % lib_json_loc)
            pass

    old_items = {}
    if os.path.isfile(lib_items_json_loc):
        logger.info("%s already exists (%s)" % (ITEMS_FILE, lib_items_json_loc))
        try:
            with open(lib_items_json_loc, "r") as f:
                old_data = json.load(f)
            for item in old_data["items"]:
                old_items[item["name"]] = item
        except:
            logger.error("Failed to read %s" % lib_items_json_loc)
            pass

    items = []
    changed = False
    for item_path in os.listdir(lib_path):
        p = os.path.join(lib_path, item_path)
        if not os.path.isdir(p):
            continue  # not interesting
        items_json = _dir2item(p, item_path, md5_enabled)
        if item_path not in old_items and updating_lib:
            changed = True
        elif item_path in old_items:
            file_changed = False
            items_json["id"] = old_items[item_path]["id"]
            items_json["created"] = old_items[item_path]["created"]
            items_json["version"] = old_items[item_path]["version"]
            file_names = set([i["name"] for i in items_json["files"]])
            old_file_names = set([i["name"] for i in old_items[item_path]["files"]])
            if file_names != old_file_names:
                # files added or removed
                changed = True
                file_changed = True
            for f in items_json["files"]:
                if file_changed:
                    break
                for old_f in old_items[item_path]["files"]:
                    if f["name"] == old_f["name"] and f["etag"] != old_f["etag"]:
                        changed = True
                        file_changed = True
                        break
            if file_changed:
                item_version = int(items_json["version"])
                items_json["version"] = str(item_version + 1)
            del old_items[item_path]
        json_item_file = ''.join((p, os.sep, ITEM_FILE))
        with open(json_item_file, "w") as f:
            json.dump(items_json, f, indent=2)
        items.append(items_json)

    if updating_lib and len(old_items) != 0:
        changed = True  # items were removed

    if updating_lib and not changed:
        logger.info("Nothing to update, quitting")
        return
    if changed:
        lib_version = int(lib_version)
        lib_version += 1
    logger.info("Saving results to %s and %s" % (lib_json_loc, lib_items_json_loc))
    with open(lib_json_loc, "w") as f:
        json.dump(_make_lib(lib_name, lib_id, lib_create, lib_version), f, indent=2)

    with open(lib_items_json_loc, "w") as f:
        json.dump(_make_items(items, lib_version), f, indent=2)


def make_vcsp_s3(lib_name, lib_path):
    """
    lib_path is the library folder path on the bucket with pattern: [bucket-name]/[object-folder-path]

    1. create new lib.json / items.json / item.json
    2. update existing lib.json / items.json / item.json

    download existing lib.json / items.json / item.json if exists
    update dir2item() 
    use last modified as the etag for files
    upload json files

    if a child folder only contains iso files, folder named by the iso file name will be created and
    item.json for the iso file will be created in that folder, and it will be deleted if the iso file
    is deleted later.
    """
    if lib_path is None or lib_path.strip() == "":
        raise Exception("The give library path on S3 is empty!")

    if not lib_path.endswith("/"):
        lib_path = lib_path + "/"

    paths = lib_path.split("/", 1)
    bucket_name = paths[0]
    lib_folder_path = paths[1]

    s3 = boto3.resource("s3")
    s3_client = boto3.client('s3')

    # check if the given s3 bucket exists
    try:
        s3.meta.client.head_bucket(Bucket=bucket_name)
    except ClientError:
        raise Exception("The give bucket %s doesn't exist or you have no access to it" % bucket_name)

    lib_json_path = lib_folder_path + LIB_FILE
    lib_items_json_path = lib_folder_path + ITEMS_FILE

    lib_id = uuid.uuid4()
    lib_create = datetime.now()
    lib_version = 1 
    updating_lib = False
    if file_exist_on_s3(s3_client, bucket_name, lib_json_path):
        logger.info("%s already exists (%s)" % (LIB_FILE, lib_json_path))
        try:
            s3_obj = s3_client.get_object(Bucket=bucket_name, Key=lib_json_path)
            old_lib = json.loads(s3_obj['Body'].read().decode('utf-8'))
            if "id" in old_lib:
                lib_id = old_lib["id"].split(":")[-1]
            if "created" in old_lib:
                lib_create = datetime.strptime(old_lib["created"], ISO_FORMAT)
            if "version" in old_lib:
                lib_version = old_lib["version"]
                updating_lib = True
        except:
            logger.error("Failed to read %s" % lib_json_path)
            pass

    old_items = {}
    if file_exist_on_s3(s3_client, bucket_name, lib_items_json_path):
        logger.info("%s already exists (%s)" % (ITEMS_FILE, lib_items_json_path))
        try:
            s3_obj = s3_client.get_object(Bucket=bucket_name, Key=lib_items_json_path)
            old_items_data = json.loads(s3_obj['Body'].read().decode('utf-8'))
            for item in old_items_data["items"]:
                old_items[item["name"]] = item
        except:
            logger.error("Failed to read %s" % lib_items_json_path)
            pass

    items = []
    changed = False

    response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=lib_folder_path, Delimiter="/")
    if response['CommonPrefixes']:
        # skip items generation if no child folders
        for child in response['CommonPrefixes']:
            p = child['Prefix']
            item_path = p.split("/")[-2]
            items_jsons = _dir2item_s3(s3_client, bucket_name, p, item_path)
            
            for item_path, items_json in items_jsons.items():
                if item_path not in old_items and updating_lib:
                    changed = True
                elif item_path in old_items:
                    file_changed = False
                    items_json["id"] = old_items[item_path]["id"]
                    items_json["created"] = old_items[item_path]["created"]
                    items_json["version"] = old_items[item_path]["version"]
                    file_names = set([i["name"] for i in items_json["files"]])
                    old_file_names = set([i["name"] for i in old_items[item_path]["files"]])
                    if file_names != old_file_names:
                        # files added or removed
                        changed = True
                        file_changed = True
                    for f in items_json["files"]:
                        if file_changed:
                            break
                        for old_f in old_items[item_path]["files"]:
                            if f["name"] == old_f["name"] and f["etag"] != old_f["etag"]:
                                changed = True
                                file_changed = True
                                break
                    if file_changed:
                        item_version = int(items_json["version"])
                        items_json["version"] = str(item_version + 1)
                    del old_items[item_path]
                json_item_file = lib_folder_path + items_json['selfHref']
                obj = s3.Object(bucket_name, json_item_file)
                obj.put(Body=json.dumps(items_json, indent=2))
                items.append(items_json)

    if updating_lib and len(old_items) != 0:
        changed = True  # items were removed, and delete old iso item folders
        for old_item_name, old_item_json in old_items.items():
            if old_item_json['type'] == VCSP_TYPE_ISO:
                # TODO: avoid deleting user created folders
                old_item_path = lib_folder_path + old_item_json['selfHref']
                last_index = old_item_path.rfind("/")
                old_item_path = old_item_path[:last_index+1]
                objects = s3.Bucket(bucket_name).objects.filter(Prefix=old_item_path)
                count = sum(1 for _ in objects)
                if count == 1:
                    objects.delete()

    if updating_lib and not changed:
        logger.info("Nothing to update, quitting")
        return
    if changed:
        lib_version = int(lib_version)
        lib_version += 1

    logger.info("Saving results to %s and %s" % (lib_json_path, lib_items_json_path))
    obj = s3.Object(bucket_name, lib_json_path)
    obj.put(Body=json.dumps(_make_lib(lib_name, lib_id, lib_create, lib_version), indent=2))

    obj = s3.Object(bucket_name, lib_items_json_path)
    obj.put(Body=json.dumps(_make_items(items, lib_version), indent=2))


def file_exist_on_s3(s3_client, bucket, file_path):
    """
    Check if the given file path exists on S3 bucket

    Args:
        s3_client: S3 client
        bucket: bucket name
        file_path: file path on S3

    Returns:
        true if the given file path exists, false otherwise.
    """
    response = s3_client.list_objects_v2(Bucket=bucket, Prefix=file_path)
    return response['KeyCount'] == 1 

def parse_options():
    """
    Parse command line options
    """
    parser = argparse.ArgumentParser(usage=usage())

    # Run options
    parser.add_argument('-n', '--name', dest='name',
                        help="library name")
    parser.add_argument('-t', '--type', dest='type',
                        default='local', help="storage type")
    parser.add_argument('-path', '--path', dest='path',
                        help="library path on storage")
    parser.add_argument('--etag', dest='etag',
                        default='true', help="generate etag")
    args = parser.parse_args()

    if args.name is None or args.path is None:
        parser.print_help()
        sys.exit(1)

    return args

def usage():
    '''
    The usage message for the argument parser.
    '''
    return """Usage: python make-vcsp-2018.py -n <library-name> -t <storage-type:local or s3, default local> -p <library-storage-path> --etag <true or false, default true>

    Note that s3 requires the following configurations:
    1. ~/.aws/config
      [default]
      region=us-west-1
    2. ~/.aws/credentials
      [default]
      aws_access_key_id = <access-key-id>
      aws_secret_access_key = <secret-access-key>
"""

def main():
    args = parse_options()

    lib_name = args.name
    storage_type = args.type
    lib_path = args.path
    md5_enabled = args.etag == 'true' or args.etag == 'True'

    # add option: storage_type, default to local, s3 via boto3
    # or https://github.com/eskil/python-s3,
    # basic auth option: https://www.yegor256.com/2014/04/21/s3-http-basic-auth.html
    # https://www.codeprocess.io/http-basic-authentication-with-s3-static-site-extend

    if "local" == storage_type:
        make_vcsp(lib_name, lib_path, md5_enabled)
    elif "s3" == storage_type:
        make_vcsp_s3(lib_name, lib_path)

if __name__ == "__main__":
    main()
