import os
import requests
import json
from datetime import datetime
from google.transit import gtfs_realtime_pb2
import pytz

# Function to create the folder if it doesn't exist
def create_folder(folder_name):
    if not os.path.exists(folder_name):
        os.makedirs(folder_name)

# Function to parse GTFS-Realtime protobuf data and convert it to a Python dictionary
def parse_proto_to_dict(proto_data):
    # Initialize the GTFS-Realtime message structure
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(proto_data)

    # Convert the protobuf message to a Python dictionary
    parsed_data = {
        "header": {
            "gtfs_realtime_version": feed.header.gtfs_realtime_version,
            "timestamp": feed.header.timestamp,
        },
        "entities": [
            {
                "id": entity.id,
                "vehicle": {
                    "trip": {
                        "trip_id": entity.vehicle.trip.trip_id,
                        "route_id": entity.vehicle.trip.route_id,
                    },
                    "position": {
                        "latitude": entity.vehicle.position.latitude,
                        "longitude": entity.vehicle.position.longitude,
                        "bearing": entity.vehicle.position.bearing,
                        "speed": entity.vehicle.position.speed,
                    } if entity.vehicle.HasField("position") else None,
                    "current_stop_sequence": entity.vehicle.current_stop_sequence,
                    "current_status": entity.vehicle.current_status,
                    "timestamp": entity.vehicle.timestamp,
                } if entity.HasField("vehicle") else None,
            }
            for entity in feed.entity
        ],
    }
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
    url = "https://romamobilita.it/sites/default/files/rome_rtgtfs_vehicle_positions_feed.pb"
    folder_name = "Rome"

    # Make a GET request to the API
    try:
        response = requests.get(url)
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
