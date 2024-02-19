//+------------------------------------------------------------------+
//|                                         AOFilteredTrendShift.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

input double hammerMaxRatio = 0.2;
input double engulfingMinRatio = 0.95;
input int aoOneColorBars = 3;
input int aoPeakPeriod = 5;
input bool debug = false;
input bool signalScreenshot = true;
input bool sendMail = true;
input bool sendCallMeBotMessage = true;

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
      Print("IndicatorRelease(aoHandle) failed. Error ", GetLastError());
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
      findEngulfing();
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
   if(ratio > hammerMaxRatio)
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
   if(ratio < engulfingMinRatio)
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
void handleSignal(string signalName, double ratio)
  {
   screenShot(signalName);
   string message;
   StringConcatenate(message, TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1), TIME_DATE | TIME_MINUTES), " ratio: ", NormalizeDouble(ratio, 3));
   Alert(signalName, " ", message);
   mail(signalName, message);
   callMeBotMessage(signalName, message);
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
      StringConcatenate(signal, Symbol(), " ", EnumToString(Period()), " ", signalName, " reported at: ", TimeToString(currentTime, TIME_DATE|TIME_SECONDS));
      printf("Sending mail: %s", signal);
      if(!SendMail(signal, mailContent))
         printf("Error sending mail %s", signal);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void callMeBotMessage(string signalName, string message)
  {
   if(sendCallMeBotMessage)
     {
      string cookie=NULL, headers;
      char   post[], result[];
      string url="https://api.callmebot.com/whatsapp.php?phone=___________&apikey=_______&text=";

      string signal;
      StringConcatenate(signal, Symbol(), " ", EnumToString(Period()), " ", signalName, " at: ", message);
      StringReplace(signal, " ", "+");
      StringConcatenate(url, url, signal);
      printf("Sending WhatsApp message: %s", url);
      int res = WebRequest("GET", url, cookie, NULL, 500, post, 0, result, headers);
      if(res == -1)
         printf("Error sending signal message: %i", GetLastError());
     }
  }
//+------------------------------------------------------------------+
