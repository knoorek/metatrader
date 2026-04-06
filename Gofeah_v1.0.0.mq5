//+------------------------------------------------------------------+
//|                                         AOFilteredTrendShift.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

input double iHammerMaxRatio = 0.2;
input double iEngulfingMinRatio = 0.95;
input int iAoOneColorBars = 3;
input int iAoPeakPeriod = 5;
input int iGatorSleepingPeriod = 55;
input int iGatorYawnsCount = 3;
input bool iDebug = false;
input bool iSignalScreenshot = true;

datetime LastPeriod;
bool GatorSleeping;
int AoHandle;
int GatorHandle;
int ScWidth = 1920;
int ScHeight = 768;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   AoHandle = iAO(Symbol(), PERIOD_CURRENT);
   if(AoHandle == INVALID_HANDLE)
     {
      Alert("Failed to create AO!");
      return (INIT_FAILED);
     }
   GatorHandle = iAlligator(Symbol(), PERIOD_CURRENT, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN);
   if(GatorHandle == INVALID_HANDLE)
     {
      Alert("Failed to create Alligator!");
      return (INIT_FAILED);
     }
   return (INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(!IndicatorRelease(AoHandle))
     {
      Print("IndicatorRelease(aoHandle) failed. Error ", GetLastError());
     }
   if(!IndicatorRelease(GatorHandle))
     {
      Print("IndicatorRelease(GatorRandle) failed. Error ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime lastPeriodCheck = iTime(Symbol(), PERIOD_CURRENT, 1);
   if(lastPeriodCheck != LastPeriod)
     {
      if(iDebug)
         printf("Checkings signals at: %s", TimeToString(lastPeriodCheck, TIME_DATE | TIME_MINUTES));
      LastPeriod = lastPeriodCheck;

      findHammers();
      findEngulfing();
      checkGatorSleeping();
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
   double high = iHigh(Symbol(), PERIOD_CURRENT, 1);
   double low = iLow(Symbol(), PERIOD_CURRENT, 1);
   double open = iOpen(Symbol(), PERIOD_CURRENT, 1);
   double close = iClose(Symbol(), PERIOD_CURRENT, 1);

   double ratio = MathAbs(open - close) / (high - low);
   if(ratio > iHammerMaxRatio)
      return;

   if(inDownTrend(2) && isLowestLow(1, 2) &&
      high - open < open - low && high - close < close - low)
     {
      handleSignal("hammer_up", ratio);
     }

   if(inUpTrend(2) && isHighestHigh(1, 2) &&
      high - open > open - low && high - close > close - low)
     {
      handleSignal("hammer_down", ratio);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void findEngulfing()
  {
   double open1 = iOpen(Symbol(), PERIOD_CURRENT, 1);
   double close1 = iClose(Symbol(), PERIOD_CURRENT, 1);
   double open2 = iOpen(Symbol(), PERIOD_CURRENT, 2);
   double close2 = iClose(Symbol(), PERIOD_CURRENT, 2);

   double ratio = MathAbs(open1 - close1) / MathAbs(open2 - close2);
   if(ratio < iEngulfingMinRatio)
      return;

   if(close2 < open2 && close1 > open1 && inDownTrend(3) && isLowestLow(2, 2))
     {
      handleSignal("bullish_engulfing", ratio);
     }

   if(close2 > open2 && close1 < open1 && inUpTrend(3) && isHighestHigh(2, 2))
     {
      handleSignal("bearish_engulfing", ratio);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkGatorSleeping()
  {
   double jaws[];
   double teeth[];
   double lips[];

   CopyBuffer(GatorHandle, 0, 1, iGatorSleepingPeriod, jaws);
   CopyBuffer(GatorHandle, 1, 1, iGatorSleepingPeriod, teeth);
   CopyBuffer(GatorHandle, 2, 1, iGatorSleepingPeriod, lips);

   int yawns = yawns(jaws, teeth, lips);
   if(iDebug)
      printf("Yawns count: %d", yawns);
   if(yawns >= iGatorYawnsCount && !GatorSleeping)
     {
      if(iDebug)
         printf("Gator sleeping, yawns: %d", yawns);
      GatorSleeping = true;
      handleSignal("gator_sleeping", yawns);
     }
   if(yawns < iGatorYawnsCount && GatorSleeping)
     {
      if(iDebug)
         printf("Gator awake");
      GatorSleeping = false;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int yawns(double &jaws[], double &teeth[], double &lips[])
  {
   int yawns = 0;
   double lastMouthPosition = 0;
   for(int i = 0; i < iGatorSleepingPeriod; i++)
     {
      datetime barTime = iTime(Symbol(), PERIOD_CURRENT, iGatorSleepingPeriod - i);
      int currentMouthPosition = mouthPosition(jaws[i], teeth[i], lips[i]);
      if(iDebug)
        {
         printf("CurrentMouthPosition at: %s, %d", TimeToString(barTime, TIME_DATE | TIME_MINUTES), currentMouthPosition);
         printf("Jaws at: %s, %+.1f", TimeToString(barTime, TIME_DATE | TIME_MINUTES), jaws[i]);
         printf("Teeth at: %s, %+.1f", TimeToString(barTime, TIME_DATE | TIME_MINUTES), teeth[i]);
         printf("Lips at: %s, %+.1f", TimeToString(barTime, TIME_DATE | TIME_MINUTES), lips[i]);
        }
      if(i == 0)
        {
         lastMouthPosition = currentMouthPosition;
         continue;
        }
      if(currentMouthPosition != lastMouthPosition && currentMouthPosition != 0 && lastMouthPosition != 0)
        {
         if(iDebug)
            printf("Yawn!");
         yawns++;
        }
      if(currentMouthPosition != 0)
        {
         lastMouthPosition = currentMouthPosition;
        }
     }
   return yawns;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int mouthPosition(double jaws, double teeth, double lips)
  {
   if(jaws > teeth && teeth > lips)
     {
      return -1;
     }
   if(jaws < teeth && teeth < lips)
     {
      return 1;
     }
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool inUpTrend(int shift)
  {
   return aoOneColorUpTrend(shift) || aoMaxLately(1);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool inDownTrend(int shift)
  {
   return aoOneColorDownTrend(shift) || aoMinLately(1);
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
         if(iDebug)
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
         if(iDebug)
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
   if(iAoOneColorBars > 0)
     {
      double buffer[];
      CopyBuffer(AoHandle, 0, shift, iAoOneColorBars, buffer);
      for(int i = 1; i < iAoOneColorBars; i++)
        {
         if(buffer[i - 1] < 0 || buffer[i] < 0 || buffer[i - 1] >= buffer[i])
            return false;
        }

      if(iDebug)
         printf("AO green for %d bars starting %d bars back", iAoOneColorBars, shift + iAoOneColorBars);
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool aoOneColorDownTrend(int shift)
  {
   if(iAoOneColorBars > 0)
     {
      double buffer[];
      CopyBuffer(AoHandle, 0, shift, iAoOneColorBars, buffer);
      for(int i = 1; i < iAoOneColorBars; i++)
        {
         if(buffer[i - 1] > 0 || buffer[i] > 0 || buffer[i - 1] <= buffer[i])
            return false;
        }

      if(iDebug)
         printf("AO red for %d bars starting %d bars back", iAoOneColorBars, shift + iAoOneColorBars);
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool aoMaxLately(int shift)
  {
   if(iAoPeakPeriod > 3)
     {
      double buffer[];
      CopyBuffer(AoHandle, 0, shift, iAoPeakPeriod, buffer);
      for(int i = 0; i < iAoPeakPeriod; i++)
        {
         if(buffer[i] < 0.0)
            return false;
        }

      for(int i = 1; i < iAoPeakPeriod - 1; i++)
        {
         if(buffer[i - 1] < buffer[i] && buffer[i] > buffer[i + 1])
           {
            if(iDebug)
               printf("AO max peak at %d bars back", iAoPeakPeriod - i);
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
   if(iAoPeakPeriod > 3)
     {
      double buffer[];
      CopyBuffer(AoHandle, 0, shift, iAoPeakPeriod, buffer);
      for(int i = 0; i < iAoPeakPeriod; i++)
        {
         if(buffer[i] > 0.0)
            return false;
        }

      for(int i = 1; i < iAoPeakPeriod - 1; i++)
        {
         if(buffer[i - 1] > buffer[i] && buffer[i] < buffer[i + 1])
           {
            if(iDebug)
               printf("AO min peak at %d bars back", iAoPeakPeriod - i);
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
void handleSignal(string signalName, double ratio)
  {
   screenShot(signalName);
   string message;
   StringConcatenate(message, TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES), " ratio: ", NormalizeDouble(ratio, 3));
   Alert(signalName, " ", message);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void screenShot(string signalName)
  {
   if(iSignalScreenshot)
     {
      string filename;
      StringConcatenate(filename, Symbol(), "_", EnumToString(Period()), "_", signalName, "_", IntegerToString(GetTickCount()), ".gif");
      StringToUpper(filename);
      ChartScreenShot(0, filename, ScWidth, ScHeight);
     }
  }

//+------------------------------------------------------------------+
