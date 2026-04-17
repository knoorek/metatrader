//+------------------------------------------------------------------+
//|                                         AOFilteredTrendShift.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.0"

const string expertVersion = "1.3.0";

input double iHammerMaxRatio = 0.33;
input int iAoOneColorBars = 3;
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

   if(inDownTrend(2) && isLowestLow(1, 2) &&
      isHammerUp(high, low, open, close))
     {
      double topWick = high - MathMax(open, close);
      double bottomWick = MathMin(open, close) - low;
      ObjectCreate(0, "hammer_up_" + IntegerToString(GetTickCount()), OBJ_ARROW_BUY, 0, iTime(Symbol(), PERIOD_CURRENT, 1), low);
      handleSignal("hammer_up", topWick / bottomWick);
     }

   if(inUpTrend(2) && isHighestHigh(1, 2) &&
      isHammerDown(high, low, open, close))
     {
      double topWick = high - MathMax(open, close);
      double bottomWick = MathMin(open, close) - low;
      ObjectCreate(0, "hammer_down_" + IntegerToString(GetTickCount()), OBJ_ARROW_SELL, 0, iTime(Symbol(), PERIOD_CURRENT, 1), high);
      handleSignal("hammer_down", bottomWick / topWick);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isHammerUp(double high, double low, double open, double close)
  {
   if(high - close > close - low)
      return false;
   if(iHammerMaxRatio == -1.0)
      return true;
   double topWick = high - MathMax(open, close);
   double bottomWick = MathMin(open, close) - low;

   if(bottomWick > 0 && topWick / bottomWick < iHammerMaxRatio)
     {
      if(iDebug)
         printf("Top wick: %f, bottom wick: %f, ratio: %f", topWick, bottomWick, topWick / bottomWick);
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isHammerDown(double high, double low, double open, double close)
  {
   if(high - close < close - low)
      return false;
   if(iHammerMaxRatio == -1.0)
      return true;
   double topWick = high - MathMax(open, close);
   double bottomWick = MathMin(open, close) - low;

   if(topWick > 0 && bottomWick / topWick < iHammerMaxRatio)
     {
      if(iDebug)
         printf("Top wick: %f, bottom wick: %f, ratio: %f", topWick, bottomWick, bottomWick / topWick);
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool inUpTrend(int shift)
  {
   return aoOneColorUpTrend(shift);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool inDownTrend(int shift)
  {
   return aoOneColorDownTrend(shift);
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
void handleSignal(string signalName, double ratio)
  {
   screenShot(signalName);
   string message;
   StringConcatenate(message, TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES), " ratio: ", NormalizeDouble(ratio, 3));
   if(iDebug)
      printf(message);
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
