//+------------------------------------------------------------------+
//|                                                   LastSignal.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

datetime g_lastBarTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   printf("init");
   return INIT_SUCCEEDED;
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
   if(isNewBar())
     {
      Alert("new bar");
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
//| Trade function                                                   |
//+------------------------------------------------------------------+
bool isNewBar()
  {
   datetime lastBarTime = iTime(Symbol(), PERIOD_CURRENT, 1);
   if(g_lastBarTime != lastBarTime)
     {
      Alert("lastBarDifferent");
      g_lastBarTime = lastBarTime;
      string filename;
      StringConcatenate(filename, Symbol(), "_", EnumToString(Period()));
      if(FileIsExist(filename))
        {
         Alert("fileExists");
         int fileHandle = FileOpen(filename, FILE_READ|FILE_TXT);
         if(fileHandle != INVALID_HANDLE)
           {
            int stringLength;
            string lastSavedBarTimeString = FileReadString(fileHandle, stringLength);
            Alert(lastSavedBarTimeString, " ", lastBarTime);
            datetime lastSavedBarTime = StringToTime(lastSavedBarTimeString);
            FileClose(fileHandle);
            if(lastSavedBarTime != lastBarTime)
              {
               FileDelete(filename);
               Alert("writing new date");
               int fileHandle = FileOpen(filename, FILE_WRITE|FILE_TXT);
               if(fileHandle != INVALID_HANDLE)
                 {
                  FileWrite(fileHandle, TimeToString(lastBarTime, TIME_DATE|TIME_MINUTES));
                  FileClose(fileHandle);
                 }
               else
                 {
                  Print("Error opening file: ", GetLastError());
                 }
               return true;
              }
           }
         else
           {
            Print("Error opening file: ", GetLastError());
           }
         return true;
        }
      else
        {
         int fileHandle = FileOpen(filename, FILE_WRITE|FILE_TXT);
         if(fileHandle != INVALID_HANDLE)
           {
            FileWrite(fileHandle, TimeToString(lastBarTime, TIME_DATE|TIME_MINUTES));
            FileClose(fileHandle);
           }
         else
           {
            Print("Error opening file: ", GetLastError());
           }
         return true;
        }
     }
   return false;
  }
//+------------------------------------------------------------------+
