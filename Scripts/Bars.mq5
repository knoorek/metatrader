//+------------------------------------------------------------------+
//|                                                         Bars.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   int file = FileOpen("HL_" + Symbol(), FILE_WRITE|FILE_ANSI, ",", CP_UTF8);
   int index = 0;
   double high = iHigh(Symbol(), PERIOD_CURRENT, index);
   datetime date;
   double low;

   Print("Start writing to file...");
   while(true)
     {
      high = iHigh(Symbol(), PERIOD_CURRENT, index);
      if(high != 0.0)
        {
         date = iTime(Symbol(), PERIOD_CURRENT, index);
         low = iLow(Symbol(), PERIOD_CURRENT, index);
         FileWrite(file, date, high, low);
         index++;
        }
      else
        {
         break;
        }
     }
   FileClose(file);
   Print("Writing to file finished, last date: ", date);
  }
//+------------------------------------------------------------------+
