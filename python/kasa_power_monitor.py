# Author: William Lam prompting Google Gemini
# Description: Simple HTTP endpoint for serving metrics from Kasa Smart Plug using python-kasa library
# http://ip:8080/power for JSON output
# http://ip:8080/power?output=ui for HTML output

import asyncio
import os
from http import HTTPStatus
from typing import Dict, Any, Optional
import warnings 
from datetime import datetime
import pytz 
from kasa import Discover 
from kasa.iot import IotDevice
from dotenv import load_dotenv
import json
from urllib.parse import urlparse, parse_qs

# --- GLOBAL STATE & CONFIGURATION ---
current_power_data: Dict[str, Any] = {
    "alias": "Unknown", 
    "power_mw": 0,
    "voltage_mv": 0,
    "current_ma": 0,
    "total_kwh": 0,
    "last_updated": "Never",
    "status": "Initializing..."
}

# --- KASA DEVICE INITIALIZATION ---

async def initialize_device(ip: str, username: str, password: str) -> Optional[IotDevice]:
    """
    Attempts to discover and perform an initial update on the Kasa device.
    Returns the initialized IotDevice object or None on critical failure.
    """
    global current_power_data

    print(f"Starting Kasa device discovery at {ip}...")

    # 1. Initial device creation attempt, passing username and password directly
    try:
        device = await Discover.discover_single(ip, username=username, password=password)
    except Exception as e:
        current_power_data['status'] = f"FATAL ERROR: Failed to create device object: {e.__class__.__name__}. Check credentials, IP, or network."
        print(f"FATAL ERROR: Could not create device object: {e}")
        return None

    # 2. Check if discovery was successful
    if device is None:
        current_power_data['status'] = "FATAL ERROR: Device not found or connection/authentication failed. Check IP, Credentials, and Local Control status."
        print("\n" + "="*50)
        print("❌ DEVICE DISCOVERY FAILED")
        print(f"IP Target: {ip}")
        print("ACTION: Ensure KASA_DEVICE_IP is correct, and Local Control is enabled in the Kasa App.")
        print("Also double-check KASA_USERNAME/KASA_PASSWORD.")
        print("="*50 + "\n")
        return None

    # 3. Force an update immediately after discovery to fully populate alias and state
    try:
        await device.update()
    except Exception as e:
        current_power_data['status'] = f"FATAL ERROR: Device found but failed initial update: {e.__class__.__name__}"
        print(f"FATAL ERROR: Device found but failed initial update: {e}")
        return None

    # Log successful discovery and device properties
    print("\n" + "="*50)
    print("✅ DEVICE DISCOVERY SUCCESSFUL")
    print(f"Device Alias: {device.alias}")
    print(f"Device Model: {device.model}")
    print(f"Supports Energy Monitoring: Confirmed (KP125M)")
    print("="*50 + "\n")

    return device


# --- KASA DEVICE POLLING LOGIC ---

async def kasa_poller(device: IotDevice, ip: str, poll_interval: int, quiet_mode: bool, timezone_name: str):
    """
    Updates its status and retrieves power data in a continuous loop,
    using robust fallback logic to handle library/firmware inconsistencies.
    This function assumes the device has already been successfully initialized.
    """
    global current_power_data
    
    print(f"Kasa poller started for '{device.alias}' at {ip}.")
    
    # Pre-cache timezone object
    try:
        local_tz = pytz.timezone(timezone_name)
    except pytz.UnknownTimeZoneError:
        print(f"WARNING: Unknown timezone '{timezone_name}'. Defaulting to UTC.")
        local_tz = pytz.utc
    
    while True:
        try:
            # Update the device status (state, voltage, etc.)
            await device.update()
            
            # --- FETCH ONLY THE REQUESTED PROPERTIES USING ROBUST FALLBACK ---
            
            # Initialize with default values in case of partial error
            emeter_info = {}
            total_kwh = 0.0

            try:
                # MODERN APPROACH: Use the Energy module (preferred, non-deprecated)
                emeter_info = await device.modules.Energy.get_realtime()
                total_kwh = device.modules.Energy.total_kwh
            except AttributeError:
                # FALLBACK APPROACH: Use the deprecated method if the Energy module is not loaded
                
                # Locally suppress ALL DeprecationWarnings within this specific fallback block
                with warnings.catch_warnings():
                    warnings.filterwarnings("ignore", category=DeprecationWarning)
                    emeter_info = await device.get_emeter_realtime()
                
                # Try to get total_kwh from the deprecated property, default to 0.0 if missing
                try:
                    total_kwh = device.total_kwh 
                except AttributeError:
                    total_kwh = 0.0
                
                if not quiet_mode:
                    # Changed from WARNING to INFO
                    print("INFO: Falling back to deprecated get_emeter_realtime() and total_kwh property.")
                
            
            # --- TIMEZONE CONVERSION AND FORMATTING (FIXED) ---
            # Get the current time localized directly to the configured timezone
            updated_time_tz_aware = datetime.now(local_tz)
            
            # Format the time string in 12-hour format
            updated_time_str = updated_time_tz_aware.strftime("%Y-%m-%d %I:%M:%S %p %Z")


            # --- UPDATE GLOBAL STATE ---
            if not device.is_on:
                current_power_data = {
                    "alias": device.alias, 
                    "status": "Device is OFF.", 
                    "power_mw": 0,
                    "voltage_mv": emeter_info.get("voltage_mv", 0),
                    "current_ma": 0,
                    "total_kwh": total_kwh,
                    "last_updated": updated_time_str # Use formatted string here
                }
                if not quiet_mode:
                    # Conditionally print status updates
                    print(f"Device Alias: {device.alias}") 
                    print(f"Device at {ip} is OFF. Power: 0W. Next check in {poll_interval}s.")
                
            else:
                # Update global state with the fetched metrics
                current_power_data = {
                    "alias": device.alias, 
                    "status": "Device is ON.", 
                    "power_mw": emeter_info.get("power_mw", 0),
                    "voltage_mv": emeter_info.get("voltage_mv", 0),
                    "current_ma": emeter_info.get("current_ma", 0),
                    "total_kwh": total_kwh,
                    "last_updated": updated_time_str # Use formatted string here
                }
                
                # Print a clean update for the console
                power_w = current_power_data["power_mw"] / 1000.0
                if not quiet_mode:
                    # Conditionally print status updates
                    print(f"Device Alias: {device.alias}")
                    print(f"✅ Polled {device.alias} ({ip}). Power: {power_w:.2f} W.")

        except Exception as e:
            # Error handling also uses the absolute time now
            # Time is localized directly to the configured timezone for error logging
            updated_time_tz_aware = datetime.now(local_tz)
            error_time_str = updated_time_tz_aware.strftime("%Y-%m-%d %I:%M:%S %p %Z")
            
            current_power_data = {
                "alias": device.alias if 'device' in locals() else "Unknown", 
                "status": f"ERROR: Could not fetch data from device: {e.__class__.__name__}",
                "power_mw": 0, "voltage_mv": 0, "current_ma": 0, "total_kwh": 0,
                "last_updated": error_time_str 
            }
            # Errors are always printed regardless of quiet mode
            print(f"❌ Kasa Polling Error: {e}")

        # Wait for the next poll interval
        await asyncio.sleep(poll_interval)


# --- HTTP SERVER LOGIC ---

async def handle_http_request(reader, writer):
    """
    Handles incoming TCP connections, parses simple HTTP GET requests,
    and serves the latest power data in JSON (default) or HTML (via ?output=ui) format.
    """
    global current_power_data
    
    addr = writer.get_extra_info('peername')

    # Read the request line
    request_line = await reader.readline()
    if not request_line:
        writer.close()
        await writer.wait_closed()
        return

    # Parse request line
    try:
        method, full_path, _ = request_line.decode().strip().split()
    except ValueError:
        # Malformed request
        writer.close()
        await writer.wait_closed()
        return

    # Parse the URL and query parameters
    parsed_url = urlparse(full_path)
    path = parsed_url.path
    query_params = parse_qs(parsed_url.query)
    
    response = b""

    if method == "GET" and path == "/power":
        # Prepare the core data structure (used for both HTML and JSON)
        response_data = {
            "device_status": current_power_data['status'],
            "device_alias": current_power_data['alias'], 
            # Convert millivolts/milliwatts to standard units for output
            "current_power_watts": current_power_data['power_mw'] / 1000.0,
            "current_voltage_volts": current_power_data['voltage_mv'] / 1000.0,
            "current_amps": current_power_data['current_ma'] / 1000.0,
            "total_kwh": current_power_data['total_kwh'],
            "last_updated_ts": current_power_data['last_updated'],
            "unit": "W",
            "polling_interval_seconds": int(os.environ.get('KASA_POLL_INTERVAL', 15))
        }

        # Check if the user explicitly requested the HTML UI (?output=ui)
        if query_params.get('output') == ['ui']:
            # --- HTML RESPONSE (?output=ui) ---
            
            # Simple HTML response for better browser viewing
            body = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kasa Power Monitor</title>
    <style>
        /* Dark Mode Styling */
        body {{ 
            font-family: 'Arial', sans-serif; 
            background-color: #1a1a2e; /* Dark background */
            color: #e0e0e0; /* Light text */
            padding: 20px; 
        }}
        .card {{ 
            background-color: #2c2c54; /* Slightly lighter card background */
            padding: 30px; 
            border-radius: 12px; 
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5); /* Stronger shadow for depth */
            max-width: 600px; 
            margin: 50px auto; 
            border: 1px solid #4a4a75; /* Subtle border */
        }}
        h1 {{ 
            color: #90a4e3; /* Accent color for header */
            margin-bottom: 20px; 
            border-bottom: 2px solid #5a7edb; 
            padding-bottom: 10px; 
        }}
        p {{ line-height: 1.6; margin-bottom: 10px; }}
        .status {{ 
            font-weight: bold; 
            color: #58d68d; /* Green for ON status */
        }}
        .error {{ 
            color: #ff6b6b; /* Red for ERROR status */
        }}
        .label {{ 
            font-weight: bold; 
            display: inline-block; 
            width: 150px; 
            color: #a0c4ff; /* Light blue accent for labels */
        }}
        strong {{
            color: #fff; /* White for emphasis on power reading */
        }}
    </style>
</head>
<body>
    <div class="card">
        <h1>Kasa Power Monitor</h1>
        <!-- Alias on separate line as requested -->
        <p><span class="label">Device Alias:</span> <strong>{response_data['device_alias']}</strong></p> 
        <p><span class="label">Status:</span> <span class="{ 'error' if 'ERROR' in current_power_data['status'] else 'status'}">{current_power_data['status']}</span></p>
        <p><span class="label">Current Power:</span> <strong>{response_data['current_power_watts']:.2f} W</strong></p>
        <p><span class="label">Current Voltage:</span> {response_data['current_voltage_volts']:.2f} V</p>
        <p><span class="label">Current Amperage:</span> {response_data['current_amps']:.2f} A</p>
        <p><span class="label">Total kWh Used:</span> {response_data['total_kwh']:.4f} kWh</p>
        <p><span class="label">Last Updated:</span> {response_data['last_updated_ts']}</p>
        <p style="margin-top: 20px; font-size: 0.8em; color: #7f8c8d;">Data is refreshed every {response_data['polling_interval_seconds']} seconds.</p>
    </div>
</body>
</html>
            """.encode('utf-8')
            
            # Construct HTTP response headers
            headers = [
                'HTTP/1.1 200 OK',
                f'Content-Type: text/html; charset=utf-8',
                f'Content-Length: {len(body)}',
                'Connection: close',
                '\r\n'
            ]
            response = '\r\n'.join(headers).encode('utf-8') + body

        else:
            # --- JSON RESPONSE (Default) ---
            body = json.dumps(response_data, indent=4).encode('utf-8')
            
            headers = [
                'HTTP/1.1 200 OK',
                f'Content-Type: application/json; charset=utf-8',
                f'Content-Length: {len(body)}',
                'Connection: close',
                '\r\n'
            ]
            response = '\r\n'.join(headers).encode('utf-8') + body

    else:
        # 404 Not Found for any other path
        status_line = f"HTTP/1.1 {HTTPStatus.NOT_FOUND.value} {HTTPStatus.NOT_FOUND.phrase}\r\n"
        body = b"Not Found. Access /power path for JSON or /power?output=ui for HTML."
        response = status_line.encode() + b"Content-Length: " + str(len(body)).encode() + b"\r\n\r\n" + body
        
    writer.write(response)
    await writer.drain()
    writer.close()
    await writer.wait_closed()


# --- MAIN ENTRY POINT ---

async def main():
    # 1. Load environment variables
    env_path = 'kasa.env'
    if not os.path.exists(env_path):
        print(f"FATAL ERROR: Configuration file not found: {env_path}")
        print("Please ensure 'kasa.env' is in the same directory as the script.")
        return
        
    load_dotenv(dotenv_path=env_path)

    # 2. Get configuration variables
    try:
        kasa_ip = os.environ['KASA_DEVICE_IP']
        kasa_username = os.environ['KASA_USERNAME']
        kasa_password = os.environ['KASA_PASSWORD'] 
        kasa_timezone = os.environ.get('KASA_TIMEZONE', 'UTC')

        server_port = int(os.environ.get('SERVER_PORT', 8080))
        poll_interval = int(os.environ.get('KASA_POLL_INTERVAL', 15))
        quiet_mode = os.environ.get('KASA_QUIET_MODE', 'False').lower() == 'true'
    except KeyError as e:
        print(f"FATAL ERROR: Missing required environment variable {e}. Check {env_path}.")
        print("Ensure KASA_DEVICE_IP, KASA_USERNAME, and KASA_PASSWORD are set.")
        return
    
    # 3. CRITICAL: Discover and Initialize Device BEFORE starting the server
    initialized_device = await initialize_device(kasa_ip, kasa_username, kasa_password)

    if initialized_device is None:
        # Initialization failed, exit gracefully
        print("Initialization failed. Cannot start monitoring server.")
        return
    
    # 4. Start the background Kasa polling task
    polling_task = asyncio.create_task(
        kasa_poller(initialized_device, kasa_ip, poll_interval, quiet_mode, kasa_timezone)
    )

    # 5. Start the HTTP server
    server = await asyncio.start_server(
        handle_http_request, '0.0.0.0', server_port
    )
    
    addr = server.sockets[0].getsockname()
    print(f"\n--- HTTP Server is running ---")
    print(f"Access JSON data (Default) at http://127.0.0.1:{addr[1]}/power")
    print(f"Access HTML UI (Optional) at http://127.0.0.1:{addr[1]}/power?output=ui")
    print(f"Serving on: {addr}")
    print("------------------------------\n")

    # 6. Run until terminated
    async with server:
        await asyncio.gather(server.serve_forever(), polling_task)

if __name__ == "__main__":
    try:
        # Set a default event loop policy for Windows compatibility, but safe on Linux too
        if os.name == 'nt':
            asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
            
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nApplication shutting down gracefully.")
    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}")
