# Haskell Chat Server

This repository contains the code for my Honors Project for CSC 345: Programming Languages.

The code can be found in the [Main.hs](app/Main.hs) file and the dependencies used in the project can be found in [ChatServer.cabal](ChatServer.cabal#L38-L42). 

This project can have multiple clients connect to a chat server in the command line and communicate with each other. Additionally, any clients that join late will be able to see a history of the chats. 

## Installation Instructions
Navigate to the directory that you want to clone this repository into.
Run the following command in the command line:

    git clone git@github.com:gaddej1/haskell_chat_server.git

Install Haskell by following these instructions.
Install Cabal by following these instructions.

## Launching the Chat Server
Run the following command in the command line:

    cabal run
    
Open another command line and run the following command to join with as many clients as you like:
  
    telnet localhost 3112
    
You can quit from a client by typing quit.
