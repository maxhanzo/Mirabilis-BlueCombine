# Mirabilis Blue --- iOS BLE Client

A native iOS application demonstrating how to build a structured,
production-oriented Bluetooth Low Energy client using **Swift, SwiftUI
and CoreBluetooth**.

This project accompanies the **Connected Devices for Mobile Engineers**
article series and communicates with the **BLE-MIRABILIS-BLUE**
reference peripheral built specifically for the series.

Rather than demonstrating CoreBluetooth APIs in isolation, the project
uses a real BLE peripheral, a documented GATT profile, encrypted
characteristics, notifications, bidirectional communication and a custom
file-transfer protocol.

> **Small devices. Big possibilities.**

------------------------------------------------------------------------

## About the Project

Mirabilis Blue is a practical BLE laboratory for mobile engineers.

The system consists of two main components:

-   **BLE-MIRABILIS-BLUE firmware** running on an nRF52840-based
    peripheral
-   **Mirabilis Blue**, the native iOS client contained in this
    repository

Together they provide a reproducible environment for exploring the
complete path from a mobile application to an embedded BLE device.

The iOS application demonstrates:

-   BLE scanning and device discovery
-   Connection and disconnection management
-   GATT service and characteristic discovery
-   Reading characteristics
-   Writing with response
-   Writing without response
-   Characteristic notifications
-   Encrypted characteristics and BLE pairing
-   Connection recovery and reconnection
-   Bidirectional file transfer over GATT
-   Transfer progress and protocol state management
-   Clean separation between CoreBluetooth and the presentation layer

------------------------------------------------------------------------

## Architecture

The application is built using **SwiftUI + MVVM + Coordinator**, with
dependency injection and protocol-oriented boundaries around the
Bluetooth infrastructure.

At a high level:

``` text
┌───────────────────────────────┐
│             UI                │
│     SwiftUI Views             │
└──────────────┬────────────────┘
               │
┌──────────────▼────────────────┐
│        View Models            │
│ Scanner / Device / Transfer   │
└──────────────┬────────────────┘
               │
┌──────────────▼────────────────┐
│      Application Services     │
│   FileTransferService, etc.   │
└──────────────┬────────────────┘
               │
┌──────────────▼────────────────┐
│       BluetoothManaging       │
│       Protocol Boundary       │
└──────────────┬────────────────┘
               │
┌──────────────▼────────────────┐
│       BluetoothManager        │
│         CoreBluetooth         │
└──────────────┬────────────────┘
               │
┌──────────────▼────────────────┐
│   BLE-MIRABILIS-BLUE Device   │
└───────────────────────────────┘
```

`BluetoothManager` owns the CoreBluetooth objects and translates
framework-specific delegate callbacks into application-level state and
events.

CoreBluetooth types are intentionally kept out of the SwiftUI views and
feature ViewModels.

The project uses a dedicated serial dispatch queue for Bluetooth
operations:

``` text
BLE callbacks → Bluetooth queue
Application events → Main actor → UI
```

For more detail, see:

-   [`ARCHITECTURE.md`](./Documentation/ARCHITECTURE.md)
-   [`BLUETOOTH_ARCHITECTURE.md`](./Documentation/BLUETOOTH_ARCHITECTURE.md)
-   [`FILE_TRANSFER.md`](./Documentation/FILE_TRANSFER.md)
-   [`UI_NAVIGATION.md`](./Documentation/UI_NAVIGATION.md)

------------------------------------------------------------------------

## BLE-MIRABILIS-BLUE Peripheral

The reference peripheral is based on the **Nordic nRF52840**.

Advertised device name:

``` text
BLE-MIRABILIS-BLUE
```

Custom service UUID:

``` text
7E57A000-0000-4B1A-9C00-000000000001
```

The custom GATT service exposes characteristics for:

  Capability               Operation
  ------------------------ ----------------------------------
  Basic value              Write
  Last written value       Read
  Observable value         Read + Notify
  Periodic event stream    Notify
  Write Without Response   Write
  Last WNR value           Read
  Secure value             Encrypted Write
  Secure state             Encrypted Read + Notify
  File Transfer RX         Encrypted Write Without Response
  File Transfer TX         Encrypted Notify
  Total Uploaded Bytes     Encrypted Read

The peripheral also exposes standard Device Information Service
characteristics.

The complete firmware and GATT specification are available in the
companion firmware repository:

**BLE-MIRABILIS-BLUE Firmware**\
https://github.com/maxhanzo/nRF52840

------------------------------------------------------------------------

## File Transfer

The project includes a custom bidirectional file-transfer protocol
implemented over two GATT characteristics:

``` text
File Transfer RX
7E57A000-0000-4B1A-9C00-00000000000B
Central → Peripheral
Write Without Response
Encrypted
```

``` text
File Transfer TX
7E57A000-0000-4B1A-9C00-00000000000C
Peripheral → Central
Notify
Encrypted
```

The protocol demonstrates:

-   Upload and download
-   Packet framing
-   Sequence numbers
-   Chunking
-   ACK/NACK flow control
-   Transfer completion
-   Cancellation
-   Error propagation
-   Little-endian binary values
-   Progress reporting

The reference firmware currently supports files up to **16 KiB** stored
in RAM.

See [`FILE_TRANSFER.md`](./Documentation/FILE_TRANSFER.md) for the
protocol implementation and design.

------------------------------------------------------------------------

## Project Structure

``` text
Mirabilis Blue
│
├── App
│   ├── AppContainer
│   └── AppCoordinator
│
├── Bluetooth
│   ├── BluetoothManaging
│   ├── BluetoothManager
│   ├── BluetoothDevice
│   ├── BluetoothEvent
│   ├── BluetoothState
│   ├── BluetoothError
│   └── MirabilisUUID
│
├── Features
│   ├── Scanner
│   ├── Device
│   └── FileTransfer
│
├── Services
│   └── FileTransferService
│
└── Utilities
```

The exact directory structure may evolve as the tutorial progresses, but
the architectural boundaries are deliberately kept explicit.

------------------------------------------------------------------------

## Requirements

-   Xcode 26 or later
-   A physical iPhone or iPad with Bluetooth support
-   BLE-MIRABILIS-BLUE compatible peripheral
-   BLE-MIRABILIS-BLUE firmware

A physical iOS device is strongly recommended because the purpose of
this project is to interact with actual BLE hardware.

------------------------------------------------------------------------

## Getting Started

Clone the repository:

``` bash
git clone https://github.com/maxhanzo/Mirabilis-Blue.git
cd Mirabilis-Blue
```

Open the Xcode project and run the application on a physical iOS device.

Flash the companion firmware onto the supported nRF52840 hardware and
verify that the peripheral advertises as:

``` text
BLE-MIRABILIS-BLUE
```

Launch the application and begin scanning.

The basic workflow is:

``` text
Scan
  ↓
Discover BLE-MIRABILIS-BLUE
  ↓
Connect
  ↓
Discover Services
  ↓
Discover Characteristics
  ↓
Read / Write / Subscribe
  ↓
Secure Operations
  ↓
File Transfer
```

------------------------------------------------------------------------

## Article Series

This repository accompanies:

### Connected Devices for Mobile Engineers

**[Part 1 — BLE Foundations](https://www.linkedin.com/pulse/part-1-ble-foundations-max-hiroyuki-ueda-dlm6f/)**

ATT, GATT, services, characteristics and the fundamentals behind BLE communication.

**[Part 2 — Building Our BLE Laboratory](https://www.linkedin.com/pulse/part-2-building-our-ble-laboratory-max-hiroyuki-ueda-w56kf/)**

Building and configuring the nRF52840-based reference peripheral used throughout the series.

**[Part 3A — Building the iOS Client with CoreBluetooth](https://www.linkedin.com/pulse/part-3a-building-ios-client-corebluetooth-max-hiroyuki-ueda-1gpif)**

Building the native iOS client and exploring its CoreBluetooth architecture and implementation.

**Part 3B — Implementing Bidirectional File Transfer over GATT**

Designing and implementing a custom file-transfer protocol on top of BLE.

*Coming soon.*

------------------------------------------------------------------------

## Why This Repository Exists

There are many excellent explanations of individual CoreBluetooth APIs.

This project has a slightly different objective.

It is intended to show how those APIs fit together when building an
application that communicates with **real hardware running real firmware
through a defined protocol**.

That means dealing not only with the happy path, but also with questions
such as:

-   Where should `CBCentralManager` live?
-   Which layer should know about `CBPeripheral`?
-   How should BLE events reach ViewModels?
-   What happens when Bluetooth is still initializing?
-   How should connection loss be handled?
-   When should pairing occur?
-   How should binary protocol data be decoded?
-   How can larger payloads be transported over GATT?
-   Which responsibilities belong to the mobile app, and which belong to
    the firmware?

Those boundaries are where much of connected-device engineering actually
happens.

------------------------------------------------------------------------

## Scope

This is an educational and experimental project.

The architecture intentionally favours **clarity, explicit behaviour and
inspectable protocol interactions** over abstraction for abstraction's
sake.

It should therefore be treated as a reference implementation and
learning environment rather than a drop-in BLE framework.

------------------------------------------------------------------------

## Contributing

Issues, discussions and suggestions are welcome.

If you experiment with the project, find an edge case, improve the
protocol, or simply implement the same ideas differently, feel free to
share what you discovered.

------------------------------------------------------------------------

## License

This project is licensed under the Apache License 2.0.

You may use, modify and distribute this software, including for commercial
purposes, subject to the terms of the license.

See the [LICENSE](./LICENSE) file for details.

Copyright © 2026 Max Hiroyuki Ueda / Mirabilis Blue.

------------------------------------------------------------------------

## Author

**Max Hiroyuki Ueda**

Mobile Software Engineer specialising in native iOS, Bluetooth Low
Energy, connected devices and IoT.

**Mirabilis Blue**

