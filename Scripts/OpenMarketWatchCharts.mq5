//+------------------------------------------------------------------+
//|                                       OpenMarketWatchCharts.mq5  |
//|                                  Copyright 2026, AI Developer    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

//--- Input parameters
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1;      // Timeframe for new charts
input string          InpTemplate  = "default.tpl";  // Template to apply (Optional)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   int totalSymbols = SymbolsTotal(true);
   PrintFormat("Found %d symbols in Market Watch.", totalSymbols);

   for(int i = 0; i < totalSymbols; i++)
     {
      string symbol_name = SymbolName(i, true);
      if(symbol_name == "")
         continue;
      long chart_id = ChartOpen(symbol_name, InpTimeframe);
      if(chart_id > 0)
        {
         PrintFormat("Successfully opened chart for %s (ID: %I64d)", symbol_name, chart_id);
         if(InpTemplate != "" && InpTemplate != "default.tpl")
           {
            if(!ChartApplyTemplate(chart_id, InpTemplate))
              {
               PrintFormat("Failed to apply template %s to %s. Error: %d", InpTemplate, symbol_name, GetLastError());
              }
           }
        }
      else
        {
         int last_error = GetLastError();
         PrintFormat("Failed to open chart for %s. Error code: %d", symbol_name, last_error);

         if(last_error == 4113) // ERR_CHART_CANNOT_OPEN
           {
            Alert("Terminal limit reached! MetaTrader 5 cannot exceed 100 open charts.");
            break;
           }
        }
     }

   Print("Script execution completed.");
  }
//+------------------------------------------------------------------+
