//+------------------------------------------------------------------+
//|                                      AOFilteredCandleSignals.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

input bool showHammers = true;
input bool showEngulfing = true;
input bool showStars = true;
input bool showHarami = true;
input int aoOneColorBars = 5;
input int aoPeakPeriod = 5;
input bool ignoreTrendCheck = false;
input bool debug = false;
input bool signalScreenshot = true;

datetime lastPeriod;
int aoHandle;
int scWidth = 1920;
int scHeight = 768;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   aoHandle = iAO(Symbol(), PERIOD_CURRENT);
   if(aoHandle == INVALID_HANDLE)
     {
      Alert("Failed to create AO!");
      return (INIT_FAILED);
     }

   return (INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(!IndicatorRelease(aoHandle))
     {
      Print("IndicatorRelease() failed. Error ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime lastPeriodCheck = iTime(Symbol(), PERIOD_CURRENT, 1);
   if(lastPeriodCheck != lastPeriod)
     {
      //printf("Checkings signals at: %s", TimeToString(lastPeriodCheck, TIME_DATE | TIME_MINUTES));
      lastPeriod = lastPeriodCheck;

      findHammers();
      findEngulfing();
      findStars();
      findHarami();
     }
  }

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
//---
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void findHammers()
  {
   if(showHammers)
     {
      double barRatio = 4.0;

      double high = iHigh(Symbol(), PERIOD_CURRENT, 1);
      double low = iLow(Symbol(), PERIOD_CURRENT, 1);
      double open = iOpen(Symbol(), PERIOD_CURRENT, 1);
      double close = iClose(Symbol(), PERIOD_CURRENT, 1);

      double spread = high - low;
      if(inDownTrend(2) &&
         open > high - spread / 2.0 && close > high - spread / 2.0 &&
         MathAbs(open - close) < spread / barRatio)
        {
         Alert("hammer up: ", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES));
         screenShot("hammerUp");
        }

      if(inUpTrend(2) &&
         open < low + spread / 2.0 && close < low + spread / 2.0 &&
         MathAbs(open - close) < spread / barRatio)
        {
         Alert("hammer down: ", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES));
         screenShot("hammerDown");
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void findEngulfing()
  {
   if(showEngulfing)
     {
      double open1 = iOpen(Symbol(), PERIOD_CURRENT, 1);
      double close1 = iClose(Symbol(), PERIOD_CURRENT, 1);
      double open2 = iOpen(Symbol(), PERIOD_CURRENT, 2);
      double close2 = iClose(Symbol(), PERIOD_CURRENT, 2);

      double bullishSpread = open2 - close2;
      if(inDownTrend(3) &&
         open2 > close2 && close1 > open2 && open1 < close2)
        {
         Alert("bullish engulfing: ", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));
         screenShot("bullishEngulfing");
        }

      double bearishSpread = close2 - open2;
      if(inUpTrend(3) &&
         close2 > open2 && open1 > close2 && close1 < open2)
        {
         Alert("bearish engulfing: ", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));
         screenShot("bearishEngulfing");
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void findStars()
  {
   if(showStars)
     {
      double barRatio = 3.0;

      double open1 = iOpen(Symbol(), PERIOD_CURRENT, 1);
      double close1 = iClose(Symbol(), PERIOD_CURRENT, 1);
      double open2 = iOpen(Symbol(), PERIOD_CURRENT, 2);
      double close2 = iClose(Symbol(), PERIOD_CURRENT, 2);
      double open3 = iOpen(Symbol(), PERIOD_CURRENT, 3);
      double close3 = iClose(Symbol(), PERIOD_CURRENT, 3);

      double morningSpread = open3 - close3;
      if(inDownTrend(4) &&
         open3 > close3 && open2 > close2 && close1 > open1 &&
         open2 >= close3 - morningSpread / barRatio && open2 < close3 + morningSpread / barRatio &&
         open1 >= close3 - morningSpread / barRatio && close1 > close3 + morningSpread / barRatio)
        {
         Alert("morning star: ", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 3), TIME_DATE | TIME_MINUTES));
         screenShot("morningStar");
        }

      double eveningSpread = close3 - open3;
      if(inUpTrend(4) &&
         open3 < close3 && open2 < close2 && close1 < open1 &&
         open2 <= close3 + eveningSpread / barRatio && open2 > close3 - eveningSpread / barRatio &&
         open1 <= close3 + eveningSpread / barRatio && close1 < close3 - eveningSpread / barRatio)
        {
         Alert("evening star: ", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 3), TIME_DATE | TIME_MINUTES));
         screenShot("eveningStar");
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void findHarami()
  {
   if(showHarami)
     {
      double barRatio = 3.0;

      double open1 = iOpen(Symbol(), PERIOD_CURRENT, 1);
      double close1 = iClose(Symbol(), PERIOD_CURRENT, 1);
      double open2 = iOpen(Symbol(), PERIOD_CURRENT, 2);
      double close2 = iClose(Symbol(), PERIOD_CURRENT, 2);

      double bearishSpread1 = open1 - close1;
      double bearishSpread2 = close2 - open2;
      if(inUpTrend(2) &&
         open2 < close2 && open1 > close1 &&
         open2 < close1 && open1 < close2 &&
         bearishSpread1 <= bearishSpread2 / barRatio)
        {
         Alert("bearish harami: ", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));
         screenShot("bearishHarami");
        }
      double bullishSpread1 = close1 - open1;
      double bullishSpread2 = open2 - close2;
      if(inDownTrend(2) &&
         open2 > close2 && open1 < close1 &&
         open2 > close1 && open1 > close2 &&
         bullishSpread1 <= bearishSpread2 / barRatio)
        {
         Alert("bullish harami: ", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));
         screenShot("bullishHarami");
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool inUpTrend(int shift)
  {
   return ignoreTrendCheck || aoOneColorUpTrend(shift) || aoMaxLately(1);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool inDownTrend(int shift)
  {
   return ignoreTrendCheck || aoOneColorDownTrend(shift) || aoMinLately(1);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool aoOneColorUpTrend(int shift)
  {
   if(aoOneColorBars > 0)
     {
      double buffer[];
      CopyBuffer(aoHandle, 0, shift, aoOneColorBars, buffer);
      for(int i = 1; i < aoOneColorBars; i++)
        {
         if(buffer[i - 1] < 0 || buffer[i] < 0 || buffer[i - 1] >= buffer[i])
           {
            return false;
           }
        }

      if(debug)
         printf("AO green for %d bars starting %d bars back", aoOneColorBars, shift + aoOneColorBars);
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool aoOneColorDownTrend(int shift)
  {
   if(aoOneColorBars > 0)
     {
      double buffer[];
      CopyBuffer(aoHandle, 0, shift, aoOneColorBars, buffer);
      for(int i = 1; i < aoOneColorBars; i++)
        {
         if(buffer[i - 1] > 0 || buffer[i] > 0 || buffer[i - 1] <= buffer[i])
           {
            return false;
           }
        }

      if(debug)
         printf("AO red for %d bars starting %d bars back", aoOneColorBars, shift + aoOneColorBars);
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool aoMaxLately(int shift)
  {
   if(aoPeakPeriod > 3)
     {
      double buffer[];
      CopyBuffer(aoHandle, 0, shift, aoPeakPeriod, buffer);
      for(int i = 0; i < aoPeakPeriod; i++)
        {
         if(buffer[i] < 0.0)
           {
            return false;
           }
        }

      for(int i = 1; i < aoPeakPeriod - 1; i++)
        {
         if(buffer[i - 1] < buffer[i] && buffer[i] > buffer[i + 1])
           {
            if(debug)
               printf("AO max peak at %d bars back", aoPeakPeriod - i);
            return true;
           }
        }

      return false;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool aoMinLately(int shift)
  {
   if(aoPeakPeriod > 3)
     {
      double buffer[];
      CopyBuffer(aoHandle, 0, shift, aoPeakPeriod, buffer);
      for(int i = 0; i < aoPeakPeriod; i++)
        {
         if(buffer[i] > 0.0)
           {
            return false;
           }
        }

      for(int i = 1; i < aoPeakPeriod - 1; i++)
        {
         if(buffer[i - 1] > buffer[i] && buffer[i] < buffer[i + 1])
           {
            if(debug)
               printf("AO min peak at %d bars back", aoPeakPeriod - i);
            return true;
           }
        }

      return false;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void screenShot(string signalName)
  {
   if(signalScreenshot)
     {
      MqlDateTime currentTime;
      TimeCurrent(currentTime);
      string filename;
      StringConcatenate(filename, Symbol(), "_", Period(), "_", signalName, "_", currentTime.year, currentTime.mon, currentTime.day, currentTime.hour, currentTime.min, ".gif");
      StringToUpper(filename);
      ChartScreenShot(0, filename, scWidth, scHeight);
     }
  }
//+------------------------------------------------------------------+
