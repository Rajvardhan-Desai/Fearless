# Fearless: A Woman Safety Application

**Fearless** is a mobile application designed to enhance the safety of women by providing real-time safety features, including a route finder based on crime data, emergency sharing capabilities, and more. The app leverages modern technologies like Firebase, Google Maps, and Twilio to ensure user security in urban environments.

## Features

1. **Safest Route Finder**  
   - The app uses crime data to find and recommend the safest routes within **Pune**.
   - The route is calculated dynamically based on crime data, ensuring users avoid dangerous areas and stay safe.
   - The safest route is calculated using Google Maps API and visualized for easy navigation.

2. **Emergency Sharing**  
   - In case of an emergency, the app allows users to send alerts to predefined emergency contacts.
   - The app uses Twilio to send SMS notifications with the user’s real-time location to their contacts, ensuring swift action can be taken.
   - Alerts include a link to the user’s live location on the map.

3. **Real-time Location Tracking**  
   - The app tracks the user’s location in real time and provides accurate navigation to ensure they are on the safest route.
   - Geolocator and Google Maps are used for accurate location tracking.

4. **User Authentication and Data Storage**  
   - The app uses Firebase Authentication for secure user login and profile management.
   - Firebase Firestore is used for storing and managing user data.

## Tech Stack

- **Frontend**:  
  - Flutter (for building the cross-platform mobile application)

- **Backend**:  
  - Firebase (for user authentication, database, and cloud functions)
  - Twilio (for SMS functionality)

- **APIs**:  
  - Google Maps API (for location tracking and route navigation)
  - Twilio API (for sending SMS alerts)
  - Geolocator (for location services)
  - Google Places API (for place suggestions)
  - SerpApi (for fetching crime data)

## Installation

### Prerequisites

- Flutter SDK (>= 3.5.3)
- Firebase Account (for Firebase services such as Authentication, Firestore, and Cloud Functions)
- Twilio Account (for SMS functionality)
- Google Maps API Key
- SerpApi API Key

### Steps to Install

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/fearless.git
   cd fearless
   
2. Install dependencies using Flutter:
   ```bash
       flutter pub get

3. Set up Firebase: 
    - Create a Firebase project at Firebase Console.
    - Set up Firebase Authentication, Firestore, and Firebase Cloud Functions.
    - Add your Firebase configuration to the project (in the google-services.json or GoogleService-Info.plist for Android/iOS).
    
4. Set up Google Maps API:
    - Create a project in the Google Cloud Console.
    - Enable the Google Maps SDK and generate an API Key.
    - Add the API key to your project in the appropriate configuration files (AndroidManifest.xml for Android or Info.plist for iOS).
      
5. Set up Twilio:
     - Create a Twilio account at Twilio Console.
     - Obtain your Twilio Account SID, Auth Token, and a Twilio phone number.
     - Add your Twilio credentials to the app.
6. Set up SerpApi:
     - Create an account on SerpApi.
     - Obtain your API Key.
     - Add your SerpApi key to the project.
       
7. Run the application:
  ```bash
       flutter run    
