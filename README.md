# KISS-TCP Bridge

## Overview

This app turns your Android phone into a wireless KISS TNC bridge. It connects to a Bluetooth-enabled KISS TNC (like a Mobilinkd TNC3 or a custom-built device) and bridges all KISS data to and from a TCP/IP network.

This allows you to use packet radio software (like Dire Wolf, UZ7HO SoundModem, or APRS clients) on a computer or other device on your local network, using your phone as the wireless link to the TNC.

## How to Use

The app has three main sections: **TCP Server**, **Bluetooth TNC**, and **Activity Log**.

### 1. Check the TCP Server

When you first start the app, the TCP server will automatically start.

- **IP Address**: This card shows your phone's current Wi-Fi IP address and the port it's listening on (e.g., `192.168.1.10:8001`). You will need this address to connect your computer's software.  
- **Server Status**: This shows if the server is running and if any clients are connected.

### 2. Connect to Your TNC

This card manages the Bluetooth connection to your KISS TNC.

- **Pair Your TNC**: Before using the app, go to your phone's Bluetooth settings and pair your TNC.  
- **Select TNC**: Tap the dropdown menu to see a list of all paired Bluetooth devices. Select your TNC from this list.  
- **Connect**: Once selected, tap the "Connect" button. The status indicator will turn green, and the log will show `TNC Connection established successfully`.

### 3. Connect Your Packet Software

Now that the bridge is active, you can connect your computer's packet radio software.

1. On your computer (which must be on the same Wi-Fi network as your phone), open your packet software (e.g., Dire Wolf).  
2. Instead of configuring a serial port, configure it to connect to a **Network KISS** (or AGWPE) port.  
3. Use the **IP Address** and **Port** shown in the app (e.g., `192.168.1.10` and `8001`).  

Once connected, your software will establish a connection to the app. The **Server Status** on the app will update to show `1 client(s) connected`.

### 4. Monitor Activity

The bridge is now fully active.

- **Activity Log**: This log shows all data moving across the bridge.
  - **TNC -> TCP (Green)**: A KISS frame received from your TNC (from the radio) and sent to your computer.  
  - **TCP -> TNC (Cyan)**: A KISS frame received from your computer and sent to your TNC (to be transmitted).  
- **Test Packet**: You can tap the "Send Test Packet" button to send a hardcoded test frame to your TNC. This is useful for verifying that the Bluetooth link is working. You will see a `USER -> TNC (Orange)` message in the log.
