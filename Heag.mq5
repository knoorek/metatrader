//+------------------------------------------------------------------+
//|                                         AOFilteredTrendShift.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.0"

const string expertVersion = "1.1.0";

input double iHammerMaxRatio = 0.2;
input double iEngulfingMinRatio = 0.95;
input int iAoOneColorBars = 3;
input int iAoPeakPeriod = 5;
input int iGatorFractalsCount = 5;
input bool iDebug = false;
input bool iSignalScreenshot = true;

struct Fractal
  {
   int               bar;
   double            value;
  };

struct MinMax
  {
   double            min;
   double            max;
  };

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
   ObjectsDeleteAll(0, 0);
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
   string labelName = "version";
   if(ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
     {
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 40);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 30);
      ObjectSetString(0, labelName, OBJPROP_TEXT, expertVersion);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 6);
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
   Fractal upFractals[];
   Fractal downFractals[];
   ArrayResize(upFractals, iGatorFractalsCount);
   ArrayResize(downFractals, iGatorFractalsCount);
   int bars = findFractals(upFractals, downFractals);
   if(iDebug)
      printf("Setting fractals up to: %s",
             TimeToString(iTime(Symbol(), PERIOD_CURRENT, bars), TIME_DATE | TIME_MINUTES)
            );

   MinMax gatorValues[];
   ArrayResize(gatorValues, bars);
   gatorMinMax(bars, gatorValues);

   bool gatorSleeping = true;
   for(int i = 0; i < iGatorFractalsCount; i++)
     {
      if(upFractals[i].value < gatorValues[upFractals[i].bar].max)
        {
         if(iDebug)
           {
            datetime barTime = iTime(Symbol(), PERIOD_CURRENT, upFractals[i].bar);
            printf("High fractal %f, lower than Gator %f, at: %s",
                   upFractals[i].value,
                   gatorValues[upFractals[i].bar].max,
                   TimeToString(barTime, TIME_DATE | TIME_MINUTES)
                  );
           }
         gatorSleeping = false;
         break;
        }
      if(downFractals[i].value > gatorValues[downFractals[i].bar].min)
        {
         if(iDebug)
           {
            datetime barTime = iTime(Symbol(), PERIOD_CURRENT, downFractals[i].bar);
            printf("Down fractal %f, higher than Gator %f, at: %s",
                   downFractals[i].value,
                   gatorValues[downFractals[i].bar].min,
                   TimeToString(barTime, TIME_DATE | TIME_MINUTES));
           }
         gatorSleeping = false;
         break;
        }
     }
   if(!GatorSleeping && gatorSleeping)
     {
      GatorSleeping = gatorSleeping;
      if(iDebug)
         printf("gator sleeping");
      handleSignal("gator_sleeping", bars);
     }
   if(GatorSleeping && !gatorSleeping)
     {
      GatorSleeping = gatorSleeping;
      if(iDebug)
         printf("gator awake");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int findFractals(Fractal &upFractals[], Fractal &downFractals[])
  {
   int upFractalsCount = 0;
   int downFractalsCount = 0;
   int bar = 3;
   while(true)
     {
      datetime barTime = iTime(Symbol(), PERIOD_CURRENT, bar);

      double prevHigh1 = iHigh(Symbol(), PERIOD_CURRENT, bar - 1);
      double prevHigh2 = iHigh(Symbol(), PERIOD_CURRENT, bar - 2);
      double currentHigh = iHigh(Symbol(), PERIOD_CURRENT, bar);
      double nextHigh1 = iHigh(Symbol(), PERIOD_CURRENT, bar + 1);
      double nextHigh2 = iHigh(Symbol(), PERIOD_CURRENT, bar + 2);
      if(currentHigh > prevHigh1 && currentHigh > prevHigh2 &&
         currentHigh > nextHigh1 && currentHigh > nextHigh2 &&
         upFractalsCount < iGatorFractalsCount)
        {
         upFractals[upFractalsCount].bar = bar;
         upFractals[upFractalsCount].value = currentHigh;
         upFractalsCount++;
         if(iDebug)
            printf("Fractal up: %.1f, at: %s, count: %d", currentHigh, TimeToString(barTime, TIME_DATE | TIME_MINUTES), upFractalsCount);
        }
      double prevLow1 = iLow(Symbol(), PERIOD_CURRENT, bar - 1);
      double prevLow2 = iLow(Symbol(), PERIOD_CURRENT, bar - 2);
      double currentLow = iLow(Symbol(), PERIOD_CURRENT, bar);
      double nextLow1 = iLow(Symbol(), PERIOD_CURRENT, bar + 1);
      double nextLow2 = iLow(Symbol(), PERIOD_CURRENT, bar + 2);
      if(currentLow < prevLow1 && currentLow < prevLow2 &&
         currentLow < nextLow1 && currentLow < nextLow2 &&
         downFractalsCount < iGatorFractalsCount)
        {
         downFractals[downFractalsCount].bar = bar;
         downFractals[downFractalsCount].value = currentLow;
         downFractalsCount++;
         if(iDebug)
            printf("Fractal down: %.1f, at: %s, count: %d", currentLow, TimeToString(barTime, TIME_DATE | TIME_MINUTES), downFractalsCount);
        }
      if(upFractalsCount == iGatorFractalsCount && downFractalsCount == iGatorFractalsCount)
         break;
      bar++;
     }
   return bar;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void gatorMinMax(int bars, MinMax &values[])
  {
   double jaw[];
   double teeth[];
   double lip[];

   CopyBuffer(GatorHandle, 0, 1, bars, jaw);
   CopyBuffer(GatorHandle, 1, 1, bars, teeth);
   CopyBuffer(GatorHandle, 2, 1, bars, lip);

   ArrayReverse(jaw);
   ArrayReverse(teeth);
   ArrayReverse(lip);

   for(int i = 0; i < bars; i++)
     {
      values[i].min = MathMin(MathMin(jaw[i], teeth[i]), MathMin(jaw[i], lip[i]));
      values[i].max = MathMax(MathMax(jaw[i], teeth[i]), MathMax(jaw[i], lip[i]));
     }
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

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
