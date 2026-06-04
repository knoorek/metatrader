//+------------------------------------------------------------------+
//|                                        OpenSavedChartsScript.mq5 |
//|                                  Copyright 2024, TradingBot      |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

input string FileName = "open_charts_symbols.txt";    //File with symbols
input ENUM_TIMEFRAMES timeFrame = PERIOD_D1;          //Chart period
input string templateName = "13WM.tpl";               //Template to apply

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   int file_handle = FileOpen(FileName, FILE_READ | FILE_TXT | FILE_ANSI);

   if(file_handle != INVALID_HANDLE)
     {
      int opened_count = 0;
      int templates_count = 0;
      while(!FileIsEnding(file_handle))
        {
         string symbol = FileReadString(file_handle);
         StringTrimLeft(symbol);
         StringTrimRight(symbol);
         if(symbol != "")
           {
            long chartID = ChartOpen(symbol, timeFrame);
            if(chartID == 0)
               Print("Error opening chart: ", GetLastError());
            if(ChartApplyTemplate(chartID, templateName))
               templates_count++;
            else
               Print("Error applying template: ", GetLastError());

            if(chartID > 0)
               opened_count++;
           }
        }
      FileClose(file_handle);
      Alert("Opened charts: ", opened_count, " template applied: ", templates_count);
     }
   else
     {
      Alert("Error opening file ", FileName);
     }
  }
//+------------------------------------------------------------------+
