module Main where

import Network.Socket
import System.IO
import Control.Exception
import Control.Concurrent
import Control.Monad (when)
import Control.Monad.Fix (fix)
import Database.HDBC
import Database.HDBC.Sqlite3

--This creates the socket, then makes it reusable.
--It then listens on TCP port 3112. 
main :: IO ()
main = do
  conn <- connectSqlite3 "chat.db"
  -- run conn "CREATE TABLE message (msg VARCHAR, name VARCHAR)" []
  run conn "DELETE FROM message" []
  commit conn
  sock <- socket AF_INET Stream 0 -- creates the socket
  setSocketOption sock ReuseAddr 1 -- makes the socket reusable
  bind sock (SockAddrInet 3112 iNADDR_ANY) -- TCP port 3112
  listen sock 2 -- max 2 connections
  channel <- newChan
  _ <- forkIO $ fix $ \loop -> do
    (_, _) <- readChan channel
    loop
  primaryLp sock channel 0  -- pass the channel into the loop

type Msg = (Int, String) -- message type e

primaryLp :: Socket -> Chan Msg -> Int -> IO ()
primaryLp sock channel mgN = do -- change msgNum
  conn <- accept sock -- accepts connection
  forkIO (connection conn channel mgN) -- run connection in a thread and pass the channel
  primaryLp sock channel $! mgN + 1 -- loop to keep accepting connections and forking threads

connection :: (Socket, SockAddr) -> Chan Msg -> Int -> IO ()
connection (sock, _) channel mgN = do
    conn <- connectSqlite3 "chat.db" -- connecting to database
    let broadcast msg = writeChan channel (mgN, msg) -- creates a way to broadcast messages in the channel
    hdl <- socketToHandle sock ReadWriteMode -- creates a handle in readwrite mode
    hSetBuffering hdl NoBuffering 

    hPutStrLn hdl "Hello! What is your name?"
    name <- fmap init (hGetLine hdl)
    broadcast ("--> " ++ name ++ " has entered the chat.")
    hPutStrLn hdl ("Welcome to the chat, " ++ name ++ "!")

    -- query from table and loop through them and print them out
    results <- quickQuery' conn "SELECT * from message" []
    let stringRows = map sqlToString results

    if length stringRows > 0
      then hPutStrLn hdl ("Here are the messages you missed out on: ")
    else hPutStrLn hdl ("No messages have been sent yet.")

    mapM_ (hPutStrLn hdl) stringRows 

    commLine <- dupChan channel -- creates a duplicate channel to be used to read from

    -- forks a thread for reading from the duplicated channel
    threadRd <- forkIO $ fix $ \loop -> do
        (nextNum, line) <- readChan commLine
        when (mgN /= nextNum) $ hPutStrLn hdl line
        loop

    handle (\(SomeException _) -> return ()) $ fix $ \loop -> do
        line <- fmap init (hGetLine hdl)
        case line of
             -- If there's an exception, then break the loop and quit
             "quit" -> hPutStrLn hdl "Bye!"
             -- Otherwise, continue broadcasting messages and committing them to the database
             _      -> do 
                run conn "INSERT INTO message (msg, name) VALUES (?, ?)" [toSql line, toSql name]
                commit conn
                broadcast (name ++ ": " ++ line) >> loop

    killThread threadRd                    -- kill the thread once done with the loop (exiting)
    broadcast ("<-- " ++ name ++ " left the chat.") -- broadcast that the user is leaving the chat
    hClose hdl                             -- close the handle


-- takes a sql value with the name and message and puts it in a string format
sqlToString :: [SqlValue] -> String
sqlToString result = do
  let firstByte = result !! 0
  let secondByte = result !! 1
  let firstStr = fromSql firstByte :: String
  let secondStr = fromSql secondByte :: String
  secondStr ++ ": " ++ firstStr