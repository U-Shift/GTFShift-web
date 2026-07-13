import os
import requests
import json
from datetime import datetime
from google.transit import gtfs_realtime_pb2
from google.protobuf.json_format import MessageToDict
import pytz

headers = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/122.0",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
}

# Function to create the folder if it doesn't exist
def create_folder(folder_name):
    if not os.path.exists(folder_name):
        os.makedirs(folder_name)

# Function to parse GTFS-Realtime protobuf data and convert it to a Python dictionary
def parse_proto_to_dict(proto_data):
    # Initialize the GTFS-Realtime message structure
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(proto_data)

    # Convert the protobuf message to a Python dictionary preserving the field names
    parsed_data = MessageToDict(feed, preserving_proto_field_name=True)
    
    # Backwards compatibility helper to support both 'entity' and 'entities'
    if "entity" in parsed_data:
        parsed_data["entities"] = parsed_data["entity"]
        
    return parsed_data

# Function to save the parsed data to a JSON file
def save_json(data, folder_name):
    # Get current timestamp in the format YYYYMMDD_HHMM
    timestamp = datetime.now(pytz.timezone('Europe/Lisbon')).strftime("%Y%m%d_%H%M%S")
    # Define the file path
    file_name = f"{timestamp}.json"
    file_path = os.path.join(folder_name, file_name)

    # Write JSON data to the file
    with open(file_path, 'w', encoding='utf-8') as file:
        json.dump(data, file, ensure_ascii=False, indent=4)

# Main script
def main():
    url = "https://openapi.emtmadrid.es/v1/bus/servicealerts/proto"
    folder_name = "Madrid"

    # Make a GET request to the API
    try:
        response = requests.get(url, timeout=30, headers=headers)
        response.raise_for_status()  # Raise HTTPError for bad responses (4xx and 5xx)

        # Parse the protobuf data
        proto_data = response.content
        parsed_data = parse_proto_to_dict(proto_data)

        # Create the folder if it doesn't exist
        create_folder(folder_name)

        # Save the parsed data to a JSON file
        save_json(parsed_data, folder_name)
        print(f"Protobuf data successfully fetched and saved as JSON in folder '{folder_name}'.")
    except requests.exceptions.RequestException as e:
        print(f"An error occurred while fetching data: {e}")
    except Exception as e:
        print(f"An error occurred while processing the data: {e}")

if __name__ == "__main__":
    main()

