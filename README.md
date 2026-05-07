# CardiKeep

CardiKeep is a comprehensive device management and location tracking ecosystem. It is designed to provide real-time location monitoring, historical tracking data, and secure user authentication across both mobile and web platforms.

## Ecosystem Overview

The CardiKeep platform is powered by three main components that communicate together to provide a seamless tracking experience:

### 1. Mobile Application (App)
- **Technology**: Built with Flutter (Dart) for iOS and Android.
- **Role**: Serves as the primary user interface for end-users on the go.
- **Key Features**: 
  - Real-time device location monitoring and status checks (e.g., Connected/Disconnected states).
  - Map-based history backtracking to visualize past location data and routes.
  - Secure user authentication and onboarding (including Didit KYC verification and password recovery).
  - Remote device management, such as toggling alarms and registering device IMEIs.

### 2. Web Dashboard (Website)
- **Role**: Provides an expanded, browser-based tracking interface and administrative portal.
- **Key Features**:
  - Accessible from any desktop or mobile browser for broader device management.
  - Allows users to oversee multiple devices simultaneously and review detailed tracking history on a larger interface.
  - Stays perfectly synced with the mobile app through a shared backend infrastructure.

### 3. Tracking Engine (Server)
- **Technology**: Traccar Server.
- **Role**: Acts as the core backend engine handling all hardware communications, data processing, and API requests.
- **Key Features**:
  - Receives, processes, and securely stores GPS coordinates directly from the physical tracking devices.
  - Provides the REST API consumed by both the Flutter mobile app and the web dashboard.
  - Handles device protocol translation, geofencing logic, and historical location data retention.
