//+------------------------------------------------------------------+
//|                                     ApplyTemplateToAllCharts.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs
//--- input parameters
input string   templateName="FWM.tpl";
input ENUM_TIMEFRAMES chartTimeFrame = PERIOD_D1;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   int appliedCount = 0;
   int errorCount = 0;
   long chartID = ChartFirst();
   while(chartID >= 0)
     {
      if(ChartPeriod(chartID) != chartTimeFrame)
         continue;
      if(ChartApplyTemplate(chartID, templateName))
        {
         appliedCount++;
        }
      else
        {
         errorCount++;
         Print("Error applying template in ", chartID, ": ", GetLastError());
        }
      chartID = ChartNext(chartID);
     }
   Alert("Template applied in: ", appliedCount, " charts. Errors: ", errorCount);
  }
//+------------------------------------------------------------------+
