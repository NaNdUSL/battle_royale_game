# Multiplayer Game Project

This project is a simple multiplayer game designed to support multiple players simultaneously. The main objective was to explore the challenges and techniques involved in building concurrent systems, particularly focusing on game development.

## Overview

The project is split into two main components:

1. **Client**: The client-side application, implemented in Java using the Processing library, provides the game interface and player controls.
2. **Server**: The server, built using Erlang, handles the multiplayer aspect of the game, managing connections, player data, game logic and synchronization between clients.

By working with these technologies, the project explores how to implement and manage concurrency, communication between clients and server, and real-time updates in a multiplayer environment.

## Features

- **Real-time Multiplayer**: Multiple players can connect and interact with each other in the game world.
- **Concurrency**: The server leverages Erlang’s lightweight processes to manage several players simultaneously.
- **Processing Library**: The client utilizes Processing to handle graphical rendering and input handling, making it simple to create a visually interactive environment.

### Prerequisites

- **Java**: Java Development Kit (JDK) is necessary to run the client.
- **Processing**: Install the Processing library (https://processing.org/) for graphical rendering.
- **Erlang**: Finally Erlang (https://www.erlang.org/) to run the server.
