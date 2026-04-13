//+------------------------------------------------------------------+
//|                                                      FTPSend.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

input bool sendFTP = false;
input bool copy = true;

string fileFilter="*.GIF";
string ftpFolder="0ftpSent\\";
string archiveFolder="0archive\\";
ushort separator='_';

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   string filename;
   long search_handle=FileFindFirst(fileFilter, filename);
   if(search_handle != INVALID_HANDLE)
     {
      do
        {
         if(FileIsExist(filename))
           {
            copyFiles(filename);
            ftpFiles(filename);
            if(!sendFTP)
               moveFiles(filename, archiveFolder);
           }
        }
      while(FileFindNext(search_handle, filename));
      FileFindClose(search_handle);
     }
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void copyFiles(string filename)
  {
   if(copy)
     {
      string destinationFileCopy;
      string filenameSplit[];
      StringSplit(filename, separator, filenameSplit);
      StringConcatenate(destinationFileCopy, filenameSplit[0], "\\", filename);
      FileCopy(filename, 0, destinationFileCopy, FILE_REWRITE);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void moveFiles(string filename, string destinationFolder)
  {
   string destinationFile;
   StringConcatenate(destinationFile, destinationFolder, filename);
   FileMove(filename, 0, destinationFile, FILE_REWRITE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ftpFiles(string filename)
  {
   if(sendFTP)
     {
      printf("Sending %s", filename);
      if(SendFTP(filename))
        {
         moveFiles(filename, ftpFolder);
         printf("%s sent and moved", filename);
        }
      else
         printf("Error sending FTP: %s", filename);
     }
  }
//+------------------------------------------------------------------+
