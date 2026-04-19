//+------------------------------------------------------------------+
//|                                         AOFilteredTrendShift.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.0"

const string expertVersion = "1.4.1";

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

int AoOneColorBars = 3;
int AoTrendingBars = 21;
double DivergenceRatio = 0.5;

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
      findFioms();
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

   if(isHammerUp(high, low, open, close) && isLowestLow(1, 2) &&
      aoOneColorDownTrend(2, AoOneColorBars) && aoInTrend(AoTrendingBars))
     {
      ObjectCreate(0, "hammer_up_" + IntegerToString(GetTickCount()), OBJ_ARROW_BUY, 0, iTime(Symbol(), PERIOD_CURRENT, 1), low);
      handleSignal("hammer_up");
     }

   if(isHammerDown(high, low, open, close) && isHighestHigh(1, 2) &&
      aoOneColorUpTrend(2, AoOneColorBars) && aoInTrend(AoTrendingBars))
     {
      ObjectCreate(0, "hammer_down_" + IntegerToString(GetTickCount()), OBJ_ARROW_SELL, 0, iTime(Symbol(), PERIOD_CURRENT, 1), high);
      handleSignal("hammer_down");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void findFioms()
  {
   if(isFractalUp() && isMouthOpeningUp(1, 5))
     {
      ObjectCreate(0, "fiom_up_" + IntegerToString(GetTickCount()), OBJ_ARROW_BUY, 0, iTime(Symbol(), PERIOD_CURRENT, 3), iHigh(Symbol(), PERIOD_CURRENT, 3));
      handleSignal("fiom_up");
     }
   if(isFractalDown() && isMouthOpeningDown(1, 5))
     {
      ObjectCreate(0, "fiom_down_" + IntegerToString(GetTickCount()), OBJ_ARROW_SELL, 0, iTime(Symbol(), PERIOD_CURRENT, 3), iLow(Symbol(), PERIOD_CURRENT, 3));
      handleSignal("fiom_down");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isHammerUp(double high, double low, double open, double close)
  {
   double hMinusC = high - close;
   double cMinusL = close - low;
   if(cMinusL > 0.0)
     {
      double ratio = hMinusC / cMinusL;
      if(ratio < DivergenceRatio)
        {
         if(iDebug)
            printf("high-close / close-low ratio %f", ratio);
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isHammerDown(double high, double low, double open, double close)
  {
   double cMinusL = close - low;
   double hMinusC = high - close;
   if(hMinusC > 0.0)
     {
      double ratio = cMinusL / hMinusC;
      if(ratio < DivergenceRatio)
        {
         if(iDebug)
            printf("close-low / high-close ratio %f", ratio);
         return true;
        }
     }
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
bool aoOneColorUpTrend(int shift, int barsCount)
  {
   if(barsCount > 0)
     {
      double buffer[];
      CopyBuffer(AoHandle, 0, shift, barsCount + 1, buffer);
      for(int i = 1; i <= barsCount; i++)
        {
         if(buffer[i - 1] < 0 || buffer[i] < 0 || buffer[i - 1] >= buffer[i])
            return false;
        }

      if(iDebug)
         printf("AO green for %d bars starting %d bars back", barsCount, shift + barsCount);
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool aoOneColorDownTrend(int shift, int barsCount)
  {
   if(barsCount > 0)
     {
      double buffer[];
      CopyBuffer(AoHandle, 0, shift, barsCount + 1, buffer);
      for(int i = 1; i <= barsCount; i++)
        {
         if(buffer[i - 1] > 0 || buffer[i] > 0 || buffer[i - 1] <= buffer[i])
            return false;
        }

      if(iDebug)
         printf("AO red for %d bars starting %d bars back", barsCount, shift + barsCount);
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool aoInTrend(int barsCount)
  {
   double ao[];
   CopyBuffer(AoHandle, 0, 1, barsCount, ao);
   int positiveAo = 0;
   int negativeAo = 0;
   for(int i = 0; i < barsCount; i++)
     {
      if(ao[i] < 0)
         negativeAo++;
      if(ao[i] > 0)
         positiveAo++;
     }
   if(positiveAo > 0 && negativeAo > 0)
     {
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isFractalUp()
  {
   double high5 = iHigh(Symbol(), PERIOD_CURRENT, 5);
   double high4 = iHigh(Symbol(), PERIOD_CURRENT, 4);
   double high3 = iHigh(Symbol(), PERIOD_CURRENT, 3);
   double high2 = iHigh(Symbol(), PERIOD_CURRENT, 2);
   double high1 = iHigh(Symbol(), PERIOD_CURRENT, 1);

   if(high5 < high3 && high4 < high3 && high2 < high3 && high1 < high3)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isFractalDown()
  {
   double low5 = iLow(Symbol(), PERIOD_CURRENT, 5);
   double low4 = iLow(Symbol(), PERIOD_CURRENT, 4);
   double low3 = iLow(Symbol(), PERIOD_CURRENT, 3);
   double low2 = iLow(Symbol(), PERIOD_CURRENT, 2);
   double low1 = iLow(Symbol(), PERIOD_CURRENT, 1);

   if(low5 > low3 && low4 > low3 && low2 > low3 && low1 > low3)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isMouthOpeningUp(int shift, int barsCount)
  {
   double jaw[];
   double teeth[];
   double lips[];

   CopyBuffer(GatorHandle, 0, shift, barsCount, jaw);
   CopyBuffer(GatorHandle, 1, shift, barsCount, teeth);
   CopyBuffer(GatorHandle, 2, shift, barsCount, lips);

   for(int i = 0; i < barsCount - 1; i++)
     {
      if(!(lips[i] > teeth[i] && teeth[i] > jaw[i]))
         return false;
      if(!(lips[i] < lips[i+1] && lips[i] - jaw[i] < lips[i+1] - jaw[i+1]))
         return false;
     }
   if(iDebug)
      printf("Mouth opening up");
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isMouthOpeningDown(int shift, int barsCount)
  {
   double jaw[];
   double teeth[];
   double lips[];

   CopyBuffer(GatorHandle, 0, shift, barsCount, jaw);
   CopyBuffer(GatorHandle, 1, shift, barsCount, teeth);
   CopyBuffer(GatorHandle, 2, shift, barsCount, lips);

   for(int i = 0; i < barsCount - 1; i++)
     {
      if(!(lips[i] < teeth[i] && teeth[i] < jaw[i]))
         return false;
      if(!(lips[i] > lips[i+1] && jaw[i]- lips[i] < jaw[i+1] - lips[i+1]))
         return false;
     }
   if(iDebug)
      printf("Mouth opening down");
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void handleSignal(string signalName)
  {
   screenShot(signalName);
   string message = TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES);
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
