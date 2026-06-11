//+------------------------------------------------------------------+
//|                                              CloseAllCharts.mq5  |
//|                                            Copyright 2026, Dziq  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   long currentChartID = ChartID();
   long chartID = ChartFirst();
   long chartsToClose[];
   int count = 0;

   while(chartID >= 0)
   {
      if(chartID != currentChartID)
      {
         ArrayResize(chartsToClose, count + 1);
         chartsToClose[count] = chartID;
         count++;
      }
      chartID = ChartNext(chartID);
   }
   for(int i = 0; i < count; i++)
   {
      ChartClose(chartsToClose[i]);
   }
   ChartClose(currentChartID);
}
//+------------------------------------------------------------------+
