//+------------------------------------------------------------------+
//|                                        OpenSavedChartsScript.mq5 |
//|                                  Copyright 2024, TradingBot      |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

//--- parametry skryptu
input string FileName = "open_charts_symbols.txt"; // Nazwa pliku z symbolami

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   int file_handle = FileOpen(FileName, FILE_READ | FILE_TXT | FILE_ANSI);

   if(file_handle != INVALID_HANDLE)
     {
      int opened_count = 0;
      while(!FileIsEnding(file_handle))
        {
         string symbol = FileReadString(file_handle);
         StringTrimLeft(symbol);
         StringTrimRight(symbol);
         if(symbol != "")
           {
            long chart_d1 = ChartOpen(symbol, PERIOD_D1);
            long chart_h4 = ChartOpen(symbol, PERIOD_H4);

            if(chart_d1 > 0 && chart_h4 > 0)
               opened_count += 2;
            else
               Print("Error opening charts for: ", symbol);
           }
        }
      FileClose(file_handle);
      Alert("Opened charts: ", opened_count);
     }
   else
     {
      Alert("Error opening file ", FileName);
     }
  }
//+------------------------------------------------------------------+
