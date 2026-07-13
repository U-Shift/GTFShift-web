import os
import requests
import json
from datetime import datetime
import pytz

# Function to create the folder if it doesn't exist
def create_folder(folder_name):
    if not os.path.exists(folder_name):
        os.makedirs(folder_name)

# Function to save the JSON data
def save_json(data, folder_name):
    # Get current timestamp in the format YYYYMMDD_HHMM
    timestamp = datetime.now(pytz.timezone('Europe/Lisbon')).strftime("%Y%m%d_%H%M%S")
    # Define the file path
    file_name = f"{timestamp}.json"
    file_path = os.path.join(folder_name, file_name)

    # Write JSON data to the file
    with open(file_path, 'w', encoding='utf-8') as file:
        json.dump(data, file, ensure_ascii=False, indent=4)


def extract_vehicle_activity(data):
    vehicle_monitoring_delivery = (
        data.get("Siri", {})
        .get("ServiceDelivery", {})
        .get("VehicleMonitoringDelivery", [])
    )

    filtered_activities = []

    for delivery in vehicle_monitoring_delivery:
        for activity in delivery.get("VehicleActivity", []):
            monitored_vehicle_journey = activity.get("MonitoredVehicleJourney", {})

            filtered_activities.append(
                {
                    "RecordedAtTime": activity.get("RecordedAtTime"),
                    "MonitoredVehicleJourney": {
                        "LineRef": monitored_vehicle_journey.get("LineRef"),
                        "FramedVehicleJourneyRef": monitored_vehicle_journey.get("FramedVehicleJourneyRef"),
                        "OriginRef": monitored_vehicle_journey.get("OriginRef"),
                        "DestinationRef": monitored_vehicle_journey.get("DestinationRef"),
                        "VehicleLocation": monitored_vehicle_journey.get("VehicleLocation"),
                        "Bearing": monitored_vehicle_journey.get("Bearing"),
                    },
                }
            )

    return filtered_activities

# Main script
def main():
    url = "https://bustime.mta.info/api/siri/vehicle-monitoring.json?version=2&key=YOURAPIKEY"
    folder_name = "MTA"

    # Make a GET request to the API
    try:
        response = requests.get(url)
        response.raise_for_status()  # Raise HTTPError for bad responses (4xx and 5xx)
        data = response.json()  # Parse the JSON response
        filtered_data = extract_vehicle_activity(data)

        # Create the folder if it doesn't exist
        create_folder(folder_name)

        # Save the JSON data to a file
        save_json(filtered_data, folder_name)
        print(f"Data successfully saved in folder '{folder_name}' as a JSON file.")
    except requests.exceptions.RequestException as e:
        print(f"An error occurred while fetching data: {e}")

if __name__ == "__main__":
    main()

