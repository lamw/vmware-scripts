#!/usr/bin/env python3
# Modified version from https://github.com/R34LUS3R/GPT3-cli/blob/main/gpt.py

import argparse
import json
import os
import sys
sys.path.append('/usr/lib/vmware/vsan/perfsvc/')
import requests
import xml.dom.minidom

# Set default values for command-line arguments
MODEL = "text-davinci-003"  # model to use
TOKEN_COUNT = 300  # number of tokens to generate
TEMPERATURE = 0.4  # temperature
TOP_P = 1  # top_p value
FREQUENCY = 0.5  # frequency penalty
PRESENCE = 0.5  # presence penalty
ESXCLI_NS = "http://www.vmware.com/Products/ESX/5.0/esxcli/"


def main():
    """Main entry point."""
    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("prompt", nargs="+", default="",
                        help="prompt to use as input for the GPT-3 model")
    args = parser.parse_args()

    # Get the OpenAI API key
    api_key = "FILL_ME_IN"

    # Set up the API request
    url = "https://api.openai.com/v1/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    data = {
        "model": MODEL,
        "prompt": ' '.join(args.prompt),
        "temperature": TEMPERATURE,
        "top_p": TOP_P,
        "frequency_penalty": FREQUENCY,
        "presence_penalty": PRESENCE,
        "max_tokens": TOKEN_COUNT,
    }

    # Send the API request
    response = requests.post(url, headers=headers, json=data)

    # Check for errors in the API response
    if response.status_code != 200:
        print("Error:", response.json()["error"])
        return

    # Extract the text from the response
    text = response.json()["choices"][0]["text"]

    # Print the output
    # print(text)

    doc = xml.dom.minidom.Document()
    outputEl = doc.createElementNS(ESXCLI_NS, "output")
    outputEl.setAttribute("xmlns", ESXCLI_NS)
    doc.appendChild(outputEl)

    structEl = doc.createElementNS(ESXCLI_NS, "structure")
    structEl.setAttribute("typeName", "Result")

    fieldEl = doc.createElementNS(ESXCLI_NS, "field")
    fieldEl.setAttribute("name", "Answer")
    structEl.appendChild(fieldEl)

    boolEl = doc.createElementNS(ESXCLI_NS, "string")
    fieldEl.appendChild(boolEl)

    boolEl.appendChild(doc.createTextNode(text.strip()))

    outputEl.appendChild(structEl)

    print(doc.toxml())


if __name__ == "__main__":
    main()
