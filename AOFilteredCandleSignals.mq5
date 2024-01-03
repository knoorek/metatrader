//+------------------------------------------------------------------+
//|                                      AOFilteredCandleSignals.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

input bool showHammers = true;
input bool showTwoCandleHammers = true;
input bool showEngulfing = true;
input bool showSimpleEngulfing = true;
input bool showStars = true;
input bool showHarami = true;
input int aoOneColorBars = 5;
input int aoPeakPeriod = 5;
input bool ignoreTrendCheck = false;
input bool reportBigPriceShift = true;
input bool debug = false;
input bool signalScreenshot = true;
input bool sendMail = true;

datetime lastPeriod;
int aoHandle;
int acHandle;
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
   acHandle = iAC(Symbol(), PERIOD_CURRENT);
   if(acHandle == INVALID_HANDLE)
     {
      Alert("Failed to create AC!");
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
      Print("IndicatorRelease(aoHandle) failed. Error ", GetLastError());
     }
   if(!IndicatorRelease(acHandle))
     {
      Print("IndicatorRelease(acHandle) failed. Error ", GetLastError());
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
      if(debug)
         printf("Checkings signals at: %s", TimeToString(lastPeriodCheck, TIME_DATE | TIME_MINUTES));
      lastPeriod = lastPeriodCheck;

      findHammers();
      findTwoCandleHammers();
      findEngulfing();
      findSimpleEngulfing();
      findStars();
      findHarami();
      bigPriceShift();
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

      double ratio = MathRound((high - low) / MathAbs(open - close));
      if(isHammerUp(open, close, high, low, barRatio) && isLowestLow(1, 2))
        {
         string message;
         StringConcatenate(message, TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES), " ratio: ", ratio, " acceleration: ", acUpAcceleration(2));
         handleSignal("hammer_up", message);
        }

      if(isHammerDown(open, close, high, low, barRatio) && isHighestHigh(1, 2))
        {
         string message;
         StringConcatenate(message, TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES), " ratio: ", ratio, " acceleration: ", acDownAcceleration(2));
         handleSignal("hammer_down", message);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void findTwoCandleHammers()
  {
   if(showTwoCandleHammers)
     {
      double barRatio = 10.0;

      double open1 = iOpen(Symbol(), PERIOD_CURRENT, 1);
      double close1 = iClose(Symbol(), PERIOD_CURRENT, 1);
      double open2 = iOpen(Symbol(), PERIOD_CURRENT, 2);
      double close2 = iClose(Symbol(), PERIOD_CURRENT, 2);

      double high1 = MathMax(open1, close1);
      double high2 = MathMax(open2, close2);
      double low1 = MathMin(open1, close1);
      double low2 = MathMin(open2, high2);

      double high = MathMax(high1, high2);
      double low = MathMin(low1, low2);

      double open = iOpen(Symbol(), PERIOD_CURRENT, 2);
      double close = iClose(Symbol(), PERIOD_CURRENT, 1);

      double ratio = MathRound((high - low) / MathAbs(open - close));
      if(isHammerUp(open, close, high, low, barRatio) && isLowestLow(2, 2))
        {
         string message;
         StringConcatenate(message, TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES), " ratio: ", ratio, " acceleration: ", acUpAcceleration(2));
         handleSignal("two_candle_hammer_up", message);
        }

      if(isHammerDown(open, close, high, low, barRatio) && isHighestHigh(2, 2))
        {
         string message;
         StringConcatenate(message, TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES), " ratio: ", ratio, " acceleration: ", acDownAcceleration(2));
         handleSignal("two_candle_hammer_down", message);
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

      if(inDownTrend(3) && isLowestLow(2, 2) &&
         open2 > close2 && close1 > open2 && open1 < close2)
         handleSignal("bullish_engulfing", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));

      if(inUpTrend(3) && isHighestHigh(2, 2) &&
         close2 > open2 && open1 > close2 && close1 < open2)
         handleSignal("bearish_engulfing", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void findSimpleEngulfing()
  {
   if(showSimpleEngulfing)
     {
      double barRatio = 3;
      
      double open1 = iOpen(Symbol(), PERIOD_CURRENT, 1);
      double close1 = iClose(Symbol(), PERIOD_CURRENT, 1);
      double open2 = iOpen(Symbol(), PERIOD_CURRENT, 2);
      double close2 = iClose(Symbol(), PERIOD_CURRENT, 2);

      double bullishSpread = open2 - close2;
      if(inDownTrend(3) && isLowestLow(2, 2) &&
         open2 > close2 && close1 > open2 + bullishSpread / barRatio)
         handleSignal("bullish_simple_engulfing", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));

      double bearishSpread = close2 - open2;
      if(inUpTrend(3) && isHighestHigh(2, 2) &&
         close2 > open2 && close1 < open2 - bearishSpread / barRatio)
         handleSignal("bearish_simple_engulfing", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));
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
      if(inDownTrend(4) && isLowestLow(3, 2) &&
         open3 > close3 && open2 > close2 && close1 > open1 &&
         open2 >= close3 - morningSpread / barRatio && open2 < close3 + morningSpread / barRatio &&
         open1 >= close3 - morningSpread / barRatio && close1 > close3 + morningSpread / barRatio)
         handleSignal("morning_star", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 3), TIME_DATE | TIME_MINUTES));

      double eveningSpread = close3 - open3;
      if(inUpTrend(4) && isHighestHigh(3, 2) &&
         open3 < close3 && open2 < close2 && close1 < open1 &&
         open2 <= close3 + eveningSpread / barRatio && open2 > close3 - eveningSpread / barRatio &&
         open1 <= close3 + eveningSpread / barRatio && close1 < close3 - eveningSpread / barRatio)
         handleSignal("evening_star", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 3), TIME_DATE | TIME_MINUTES));
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

      double bullishSpread1 = close1 - open1;
      double bullishSpread2 = open2 - close2;
      if(inDownTrend(2) && isLowestLow(2, 2) &&
         open2 > close2 && open1 < close1 &&
         open2 > close1 && open1 > close2 &&
         bullishSpread1 <= bullishSpread2 / barRatio)
         handleSignal("bullish_harami", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));

      double bearishSpread1 = open1 - close1;
      double bearishSpread2 = close2 - open2;
      if(inUpTrend(2) && isHighestHigh(2, 2) &&
         open2 < close2 && open1 > close1 &&
         open2 < close1 && open1 < close2 &&
         bearishSpread1 <= bearishSpread2 / barRatio)
         handleSignal("bearish_harami", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 2), TIME_DATE | TIME_MINUTES));
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void bigPriceShift()
  {
   if(reportBigPriceShift)
     {
      int periodsCount = 24;
      double changeRatio = 2.0;

      double periodLow = INT_MAX;
      double periodHigh = INT_MIN;
      for(int i = 1; i <= periodsCount; i++)
        {
         double low = iLow(Symbol(), PERIOD_CURRENT, i);
         double high = iHigh(Symbol(), PERIOD_CURRENT, i);
         if(low < periodLow)
            periodLow = low;
         if(high > periodHigh)
            periodHigh = high;
        }
      double periodSpread = periodHigh - periodLow;

      double low = iLow(Symbol(), PERIOD_CURRENT, 1);
      double high = iHigh(Symbol(), PERIOD_CURRENT, 1);
      double spread = high - low;

      if(periodSpread / changeRatio < spread)
         handleSignal("big_hourly_price_change", TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES));
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
bool isHammerUp(double open, double close, double high, double low, double barRatio)
  {
   double spread = high - low;
   if(inDownTrend(2) &&
      open > high - spread / 2.0 && close > high - spread / 2.0 &&
      MathAbs(open - close) < spread / barRatio)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isHammerDown(double open, double close, double high, double low, double barRatio)
  {
   double spread = high - low;
   if(inUpTrend(2) &&
      open < low + spread / 2.0 && close < low + spread / 2.0 &&
      MathAbs(open - close) < spread / barRatio)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isHighestHigh(int currentBar, int barsBack)
  {
   double currentBarHigh = iHigh(Symbol(), PERIOD_CURRENT, currentBar);
   for(int i = currentBar + 1; i <= currentBar + barsBack; i++)
     {
      if(iHigh(Symbol(), PERIOD_CURRENT, i) > currentBarHigh)
        {
         if(debug)
            printf("higher high at: %d", i);
         return false;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isLowestLow(int currentBar, int barsBack)
  {
   double currentBarLow = iLow(Symbol(), PERIOD_CURRENT, currentBar);
   for(int i = currentBar + 1; i <= currentBar + barsBack; i++)
     {
      if(iLow(Symbol(), PERIOD_CURRENT, i) < currentBarLow)
        {
         if(debug)
            printf("lower low at: %d", i);
         return false;
        }
     }
   return true;
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
            return false;
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
            return false;
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
int acUpAcceleration(int shift)
  {
   double buffer[];
   int barsToCheck = 10;

   int oneColorBars = 0;
   CopyBuffer(acHandle, 0, shift, barsToCheck, buffer);
   for(int i = barsToCheck - 1; i > 0; i--)
     {
      if(buffer[i] > buffer[i - 1])
         oneColorBars++;
      else
         break;
     }
   return oneColorBars;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int acDownAcceleration(int shift)
  {
   double buffer[];
   int barsToCheck = 10;

   int oneColorBars = 0;
   CopyBuffer(acHandle, 0, shift, barsToCheck, buffer);
   for(int i = barsToCheck - 1; i > 0; i--)
     {
      if(buffer[i] < buffer[i - 1])
         oneColorBars++;
      else
         break;
     }
   return oneColorBars;
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
            return false;
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
            return false;
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
void handleSignal(string signalName, string message)
  {
   Alert(signalName, " ", message);
   screenShot(signalName);
   mail(signalName, message);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void screenShot(string signalName)
  {
   if(signalScreenshot)
     {
      string filename;
      StringConcatenate(filename, Symbol(), "_", EnumToString(Period()), "_", signalName, "_", IntegerToString(GetTickCount()), ".gif");
      StringToUpper(filename);
      ChartScreenShot(0, filename, scWidth, scHeight);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void mail(string signalName, string mailContent)
  {
   if(sendMail)
     {
      string signal;
      datetime currentTime = TimeCurrent();
      StringConcatenate(signal, Symbol(), " ", EnumToString(Period()), " ", signalName, " at: ", TimeToString(currentTime, TIME_DATE|TIME_SECONDS));
      printf("Sending mail: %s", signal);
      if(!SendMail(signal, mailContent))
         printf("Error sending mail %s", signal);
     }
  }
//+------------------------------------------------------------------+
