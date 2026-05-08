//+------------------------------------------------------------------+
//|                                        SaveOpenChartsSymbols.mq5 |
//|                                  Copyright 2024, TradingBot      |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

//--- parametry skryptu
input string FileName = "open_charts_symbols.txt"; // Nazwa pliku wyjściowego

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   int file_handle = FileOpen(FileName, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(file_handle != INVALID_HANDLE)
     {
      long chart_id = ChartFirst();
      int count = 0;
      while(chart_id >= 0)
        {
         string symbol = ChartSymbol(chart_id);
         FileWrite(file_handle, symbol);
         count++;
         chart_id = ChartNext(chart_id);
        }
      FileClose(file_handle);
      Alert("Saved: ", count, " to: ", FileName);
     }
   else
     {
      Alert("Error: ", GetLastError());
     }
  }
//+------------------------------------------------------------------+
