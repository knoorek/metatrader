//+------------------------------------------------------------------+
//|                                     DeleteObjectsInAllCharts.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
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
      // Nałóż szablon na bieżący chartID w pętli
      if(ObjectsDeleteAll(chartID))
      {
         appliedCount++;
      }
      else
      {
         errorCount++;
         Print("Error deleting objects in ", chartID, ": ", GetLastError());
      }
      chartID = ChartNext(chartID);
   }
   Alert("Deleted objects in: ", appliedCount, " charts. Errors: ", errorCount);
}
//+------------------------------------------------------------------+
