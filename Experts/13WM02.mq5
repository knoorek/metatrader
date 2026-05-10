//+------------------------------------------------------------------+
//|                                                     13WM_new.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

enum AlligatorFilter
  {
   BELOW_ALLIGATOR,
   ABOVE_ALLIGATOR
  };

enum AlligatorMouth
  {
   OPEN_UP,
   OPEN_DOWN
  };

enum Peak
  {
   MIN,
   MAX
  };

enum SingalDirection
  {
   SIGNAL_UP,
   SIGNAL_DOWN
  };

input bool DB = true;   //report divergent bar
input bool DB2 = true;  //report two divergent bars
input bool SH = true;   //report super hammer
input bool JF = true;   //report first fractal above/below jaw
input bool OMF = true;  //report first fractal above/below open mouth

//--- Alligator parameters (classic Bill Williams) - fixed
const int JawPeriod   = 13;
const int JawShift    = 8;
const int TeethPeriod = 8;
const int TeethShift  = 5;
const int LipsPeriod  = 5;
const int LipsShift   = 3;

//--- Super hammer parameters
const double MaxWickSize = 0.33;
const double MaxBodySize = 0.2;

// screenshot settings
const int  ShotWidth  = 1920;
const int  ShotHeight = 768;

int AlligatorHandle = INVALID_HANDLE;
int FractHandle = INVALID_HANDLE;
int AoHandle = INVALID_HANDLE;

//--- last closed bar time processed
datetime LastBarTime;
//--- fractal above/below jaw
datetime LastFAJBarDateTime;
datetime LastFBJBarDateTime;
//--- fractal above/below mouth
datetime LastFAOMBarDateTime;
datetime LastFBOMJBarDateTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   AlligatorHandle = iAlligator(
                        _Symbol, PERIOD_CURRENT,
                        JawPeriod,   JawShift,
                        TeethPeriod, TeethShift,
                        LipsPeriod,  LipsShift,
                        MODE_SMMA, PRICE_MEDIAN
                     );
   if(AlligatorHandle == INVALID_HANDLE)
     {
      Alert("Failed to create Alligator handle");
      return(INIT_FAILED);
     }
   FractHandle = iFractals(_Symbol, PERIOD_CURRENT);
   if(FractHandle == INVALID_HANDLE)
     {
      Alert("Failed to create Fractals handle");
      return(INIT_FAILED);
     }
   AoHandle = iAO(_Symbol, PERIOD_CURRENT);
   if(AoHandle == INVALID_HANDLE)
     {
      Alert("Failed to create AO handle");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(AlligatorHandle != INVALID_HANDLE)
      IndicatorRelease(AlligatorHandle);
   if(FractHandle != INVALID_HANDLE)
      IndicatorRelease(FractHandle);
   if(AoHandle != INVALID_HANDLE)
      IndicatorRelease(AoHandle);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(barTime == LastBarTime)
      return;

   if(DB && isDivergentBarUp(1))
     {
      string msg = StringFormat("Divergent bar up (%s) on %s %s at bar time %s",
                                EnumToString(SIGNAL_UP), _Symbol, EnumToString(Period()),
                                TimeToString(barTime, TIME_DATE|TIME_SECONDS));

      drawDivergentArrow("DB", SIGNAL_UP, barTime);
      saveSignalScreenshot("DB_UP", barTime);
      Print(msg);
     }
   if(DB && isDivergentBarDown(1))
     {
      string msg = StringFormat("Divergent bar down (%s) on %s %s at bar time %s",
                                EnumToString(SIGNAL_DOWN), _Symbol, EnumToString(Period()),
                                TimeToString(barTime, TIME_DATE|TIME_SECONDS));

      drawDivergentArrow("DB", SIGNAL_DOWN, barTime);
      saveSignalScreenshot("DB_DOWN", barTime);
      Print(msg);
     }

   if(DB2 && isTwoBarDivergenceUp(1))
     {
      string msg = StringFormat("Two divergent bars up (%s) on %s %s at bar time %s",
                                EnumToString(SIGNAL_UP), _Symbol, EnumToString(Period()),
                                TimeToString(barTime, TIME_DATE|TIME_SECONDS));

      drawDivergentArrow("2DB", SIGNAL_UP, barTime);
      saveSignalScreenshot("2DB_UP", barTime);
      Print(msg);
     }
   if(DB2 && isTwoBarDivergenceDown(1))
     {
      string msg = StringFormat("Two divergent bars down (%s) on %s %s at bar time %s",
                                EnumToString(SIGNAL_DOWN), _Symbol, EnumToString(Period()),
                                TimeToString(barTime, TIME_DATE|TIME_SECONDS));

      drawDivergentArrow("2DB", SIGNAL_DOWN, barTime);
      saveSignalScreenshot("2DB_DOWN", barTime);
      Print(msg);
     }

   if(SH && isSuperHammerUp(1))
     {
      string msg = StringFormat("Super hammer bar up (%s) on %s %s at bar time %s",
                                EnumToString(SIGNAL_UP), _Symbol, EnumToString(Period()),
                                TimeToString(barTime, TIME_DATE|TIME_SECONDS));

      drawDivergentArrow("SH", SIGNAL_UP, barTime);
      saveSignalScreenshot("SH_UP", barTime);
      Print(msg);
     }
   if(SH && isSuperHammerDown(1))
     {
      string msg = StringFormat("Super hammer bar up (%s) on %s %s at bar time %s",
                                EnumToString(SIGNAL_DOWN), _Symbol, EnumToString(Period()),
                                TimeToString(barTime, TIME_DATE|TIME_SECONDS));

      drawDivergentArrow("SH", SIGNAL_DOWN, barTime);
      saveSignalScreenshot("SH_DOWN", barTime);
      Print(msg);
     }
   int fractalBarShift = 3;
   if(JF && isFirstFractalAboveJaw(1))
     {
      string msg = StringFormat(
                      "UP FRACTAL: last up fractal is FIRST above Jaw on %s %s (fractal bar time %s)",
                      _Symbol, EnumToString(Period()),
                      TimeToString(iTime(_Symbol, PERIOD_CURRENT, fractalBarShift), TIME_DATE|TIME_SECONDS)
                   );

      drawFractalArrow(SIGNAL_UP, fractalBarShift, iLow(_Symbol, PERIOD_CURRENT, fractalBarShift));
      saveSignalScreenshot("JF_UP", barTime);
      Print(msg);
     }
   if(JF && isFirstFractalBelowJaw(1))
     {
      string msg = StringFormat(
                      "DOWN FRACTAL: last down fractal is FIRST below Jaw on %s %s (fractal bar time %s)",
                      _Symbol, EnumToString(Period()),
                      TimeToString(iTime(_Symbol, PERIOD_CURRENT, fractalBarShift), TIME_DATE|TIME_SECONDS)
                   );

      drawFractalArrow(SIGNAL_DOWN, fractalBarShift, iHigh(_Symbol, PERIOD_CURRENT, fractalBarShift));
      saveSignalScreenshot("JF_DOWN", barTime);
      Print(msg);
     }

   if(OMF && isFirstFractalAboveMouth(1))
     {
      string msg = StringFormat(
                      "UP FRACTAL: last up fractal is FIRST above Open Mouth on %s %s (fractal bar time %s)",
                      _Symbol, EnumToString(Period()),
                      TimeToString(iTime(_Symbol, PERIOD_CURRENT, fractalBarShift), TIME_DATE|TIME_SECONDS)
                   );
      drawFractalArrow(SIGNAL_UP, fractalBarShift, iHigh(_Symbol, PERIOD_CURRENT, fractalBarShift));
      saveSignalScreenshot("OMF_UP", barTime);
      Print(msg);
     }
   if(OMF && isFirstFractalBelowMouth(1))
     {
      string msg = StringFormat(
                      "DOWN FRACTAL: last down fractal is FIRST below Open Mouth on %s %s (fractal bar time %s)",
                      _Symbol, EnumToString(Period()),
                      TimeToString(iTime(_Symbol, PERIOD_CURRENT, fractalBarShift), TIME_DATE|TIME_SECONDS)
                   );

      drawFractalArrow(SIGNAL_DOWN, fractalBarShift, iLow(_Symbol, PERIOD_CURRENT, fractalBarShift));
      saveSignalScreenshot("OMF_DOWN", barTime);
      Print(msg);
     }

   LastBarTime = barTime;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isDivergentBarUp(int shift)
  {
   if(shift + 1 >= Bars(_Symbol, PERIOD_CURRENT))
      return false;

   double curLow   = iLow(_Symbol, PERIOD_CURRENT, shift);
   double curHigh  = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double curClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevLow  = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double mid      = (curHigh + curLow) / 2.0;

   if(!(curLow < prevLow && curClose > mid))
      return false;
   if(!filterWithAlligator(shift, BELOW_ALLIGATOR))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isDivergentBarDown(int shift)
  {
   if(shift + 1 >= Bars(_Symbol, PERIOD_CURRENT))
      return false;

   double curLow   = iLow(_Symbol, PERIOD_CURRENT, shift);
   double curHigh  = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double curClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double mid      = (curHigh + curLow) / 2.0;

   if(!(curHigh > prevHigh && curClose < mid))
      return false;
   if(!filterWithAlligator(shift, ABOVE_ALLIGATOR))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isTwoBarDivergenceUp(int shift)
  {
   if(shift + 1 >= Bars(_Symbol, PERIOD_CURRENT))
      return false;

   double twoBarsLow = MathMin(iLow(_Symbol, PERIOD_CURRENT, shift), iLow(_Symbol, PERIOD_CURRENT, shift + 1));
   double twoBarsHigh = MathMax(iHigh(_Symbol, PERIOD_CURRENT, shift), iHigh(_Symbol, PERIOD_CURRENT, shift + 1));
   double curOpen  = iOpen(_Symbol, PERIOD_CURRENT, shift + 1);
   double curClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevLow  = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   double wick     = twoBarsHigh - curClose;
   double barSize  = twoBarsHigh - twoBarsLow;

   if(!(prevLow > twoBarsLow))
      return false;
   if(!(wick / barSize <= MaxWickSize))
      return false;
   if(!(curClose > curOpen))
      return false;
   if(!filterWithAlligator(shift, BELOW_ALLIGATOR))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isTwoBarDivergenceDown(int shift)
  {
   if(shift + 1 >= Bars(_Symbol, PERIOD_CURRENT))
      return false;

   double twoBarsLow = MathMin(iLow(_Symbol, PERIOD_CURRENT, shift), iLow(_Symbol, PERIOD_CURRENT, shift + 1));
   double twoBarsHigh = MathMax(iHigh(_Symbol, PERIOD_CURRENT, shift), iHigh(_Symbol, PERIOD_CURRENT, shift + 1));
   double curOpen  = iOpen(_Symbol, PERIOD_CURRENT, shift + 1);
   double curClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevHigh  = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double wick     = curClose - twoBarsLow;
   double barSize  = twoBarsHigh - twoBarsLow;

   if(!(prevHigh < twoBarsHigh))
      return false;
   if(!(wick / barSize <= MaxWickSize))
      return false;
   if(!(curClose < curOpen))
      return false;
   if(!filterWithAlligator(shift, ABOVE_ALLIGATOR))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isSuperHammerUp(int shift)
  {
   if(shift + 1 >= Bars(_Symbol, PERIOD_CURRENT))
      return false;

   double curLow   = iLow(_Symbol, PERIOD_CURRENT, shift);
   double curHigh  = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double curOpen  = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double curClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevLow  = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double wick     = curHigh - curClose;
   double body     = MathAbs(curClose - curOpen);
   double barSize  = curHigh - curLow;

   if(!(prevLow > curLow))
      return false;
   if(!(wick / barSize <= MaxWickSize))
      return false;
   if(!(body / barSize <= MaxBodySize))
      return false;
   if(!filterWithAlligator(shift, BELOW_ALLIGATOR))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isSuperHammerDown(int shift)
  {
   if(shift + 1 >= Bars(_Symbol, PERIOD_CURRENT))
      return false;

   double curLow   = iLow(_Symbol, PERIOD_CURRENT, shift);
   double curHigh  = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double curOpen  = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double curClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double wick     = curClose - curLow;
   double body     = MathAbs(curClose - curOpen);
   double barSize  = curHigh - curLow;

   if(!(prevHigh < curHigh))
      return false;
   if(!(wick / barSize <= MaxWickSize))
      return false;
   if(!(body / barSize <= MaxBodySize))
      return false;
   if(!filterWithAlligator(shift, ABOVE_ALLIGATOR))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| Fractal / Jaw conditions                                         |
//+------------------------------------------------------------------+
bool isFirstFractalAboveJaw(int shift)
  {
   if(FractHandle == INVALID_HANDLE || AlligatorHandle == INVALID_HANDLE)
      return false;

   int start = MathMax(shift, 3);
   int end   = MathMin(start + 100, Bars(_Symbol, PERIOD_CURRENT) - 4); // limit search window

   int f0 = -1; // most recent up fractal
   int f1 = -1; // previous up fractal

   for(int s = start; s < end; s++)
     {
      if(IsUpFractal(s))
        {
         if(f0 == -1)
            f0 = s;
         else
           {
            f1 = s;
            break;
           }
        }
     }
   if(f0 == -1)
      return false;

   double jaw0 = getAlligatorMinMax(f0, MAX);
   if(jaw0 == 0.0 || iHigh(_Symbol, PERIOD_CURRENT, f0) <= jaw0)
      return false;

   double jaw1 = getAlligatorMinMax(f1, MAX);
   if(jaw1 == 0.0)
      return false;

   if(iHigh(_Symbol, PERIOD_CURRENT, f1) <= jaw1)
     {
      datetime lastFractalTime = iTime(_Symbol, PERIOD_CURRENT, f0);
      if(lastFractalTime != LastFAJBarDateTime)
        {
         LastFAJBarDateTime = lastFractalTime;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isFirstFractalBelowJaw(const int shift)
  {
   if(FractHandle == INVALID_HANDLE || AlligatorHandle == INVALID_HANDLE)
      return false;

   int start = MathMax(shift, 3);
   int end   = MathMin(start + 100, Bars(_Symbol, PERIOD_CURRENT) - 4); // limit search window

   int f0 = -1; // most recent down fractal
   int f1 = -1; // previous down fractal

   for(int s = start; s < end; s++)
     {
      if(IsDownFractal(s))
        {
         if(f0 == -1)
            f0 = s;
         else
           {
            f1 = s;
            break;
           }
        }
     }
   if(f0 == -1)
      return false;

   double jaw0 = getAlligatorMinMax(f0, MIN);
   if(jaw0 == 0.0 || iLow(_Symbol, PERIOD_CURRENT, f0) >= jaw0)
      return false;

   double jaw1 = getAlligatorMinMax(f1, MIN);
   if(jaw1 == 0.0)
      return false;

   if(iLow(_Symbol, PERIOD_CURRENT, f1) >= jaw1)
     {
      datetime lastFractalTime = iTime(_Symbol, PERIOD_CURRENT, f0);
      if(lastFractalTime != LastFBJBarDateTime)
        {
         LastFBJBarDateTime = lastFractalTime;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Fractal / Open mouth conditions                                  |
//+------------------------------------------------------------------+
bool isFirstFractalAboveMouth(int shift)
  {
   if(FractHandle == INVALID_HANDLE || AlligatorHandle == INVALID_HANDLE)
      return false;

   int start = MathMax(shift, 3);
   int end   = MathMin(start + 100, Bars(_Symbol, PERIOD_CURRENT) - 4); // limit search window

   int f0 = -1; // most recent up fractal
   int f1 = -1; // previous up fractal

   for(int s = start; s < end; s++)
     {
      if(IsUpFractal(s))
        {
         if(f0 == -1)
            f0 = s;
         else
           {
            f1 = s;
            break;
           }
        }
     }
   if(f0 == -1)
      return false;

   double jaw0 = getAlligatorMinMax(f0, MAX);
   if(jaw0 == 0.0 || iHigh(_Symbol, PERIOD_CURRENT, f0) <= jaw0)
      return false;

   if(!isAlligatorMouthOpen(f1, OPEN_UP) && isAlligatorMouthOpen(f0, OPEN_UP))
     {
      datetime lastFractalTime = iTime(_Symbol, PERIOD_CURRENT, f0);
      if(lastFractalTime != LastFAOMBarDateTime)
        {
         LastFAOMBarDateTime = lastFractalTime;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Fractal / Open mouth conditions                                  |
//+------------------------------------------------------------------+
bool isFirstFractalBelowMouth(int shift)
  {
   if(FractHandle == INVALID_HANDLE || AlligatorHandle == INVALID_HANDLE)
      return false;

   int start = MathMax(shift, 3);
   int end   = MathMin(start + 100, Bars(_Symbol, PERIOD_CURRENT) - 4); // limit search window

   int f0 = -1; // most recent up fractal
   int f1 = -1; // previous up fractal

   for(int s = start; s < end; s++)
     {
      if(IsUpFractal(s))
        {
         if(f0 == -1)
            f0 = s;
         else
           {
            f1 = s;
            break;
           }
        }
     }
   if(f0 == -1)
      return false;

   double jaw0 = getAlligatorMinMax(f0, MAX);
   if(jaw0 == 0.0 || iHigh(_Symbol, PERIOD_CURRENT, f0) <= jaw0)
      return false;

   if(!isAlligatorMouthOpen(f1, OPEN_DOWN) && isAlligatorMouthOpen(f0, OPEN_DOWN))
     {
      datetime lastFractalTime = iTime(_Symbol, PERIOD_CURRENT, f0);
      if(lastFractalTime != LastFBOMJBarDateTime)
        {
         LastFBOMJBarDateTime = lastFractalTime;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsUpFractal(const int shift)
  {
   if(FractHandle == INVALID_HANDLE)
      return false;
   double buff[1];
   if(CopyBuffer(FractHandle, 0, shift, 1, buff) != 1)
     {
      Print("ERROR: ", GetLastError());
      return false;
     }
   return (buff[0] != 0.0 && buff[0] != EMPTY_VALUE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDownFractal(const int shift)
  {
   if(FractHandle == INVALID_HANDLE)
      return false;
   double buff[1];
   if(CopyBuffer(FractHandle, 1, shift, 1, buff) != 1)
     {
      Print("ERROR: ", GetLastError());
      return false;
     }
   return (buff[0] != 0.0 && buff[0] != EMPTY_VALUE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool filterWithAlligator(int shift, AlligatorFilter af)
  {
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);

   if(af == BELOW_ALLIGATOR)
     {
      double jawCur = getAlligatorMinMax(shift, MIN);
      double jawPrev = getAlligatorMinMax(shift + 1, MIN);
      if(jawCur == 0.0 || jawPrev == 0.0)
         return false;
      return (close < jawCur && jawCur < jawPrev);
     }
   if(af == ABOVE_ALLIGATOR)
     {
      double jawCur = getAlligatorMinMax(shift, MAX);
      double jawPrev = getAlligatorMinMax(shift + 1, MAX);
      if(jawCur == 0.0 || jawPrev == 0.0)
         return false;
      return (close > jawCur && jawCur > jawPrev);
     }
   Alert("Unhandled AlligatorFilter value!");
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getAlligatorMinMax(const int shift, Peak peak)
  {
   if(AlligatorHandle == INVALID_HANDLE)
      return 0.0;

   double jaw[1];
   double teeth[1];
   double lips[1];
   if(CopyBuffer(AlligatorHandle, 0, shift, 1, jaw) != 1 ||
      CopyBuffer(AlligatorHandle, 1, shift, 1, teeth) != 1 ||
      CopyBuffer(AlligatorHandle, 2, shift, 1, lips) != 1)
     {
      Print("ERROR: ", GetLastError());
      return 0.0;
     }
   if(peak == MIN)
      return MathMin(MathMin(jaw[0], teeth[0]), lips[0]);
   if(peak == MAX)
      return MathMax(MathMax(jaw[0], teeth[0]), lips[0]);
   return 0.0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isAlligatorMouthOpen(const int shift, AlligatorMouth am)
  {
   if(AlligatorHandle == INVALID_HANDLE)
      return false;

   double jaw[1];
   double teeth[1];
   double lips[1];
   if(CopyBuffer(AlligatorHandle, 0, shift, 1, jaw) != 1 ||
      CopyBuffer(AlligatorHandle, 1, shift, 1, teeth) != 1 ||
      CopyBuffer(AlligatorHandle, 2, shift, 1, lips) != 1)
     {
      Print("ERROR: ", GetLastError());
      return false;
     }
   if(am == OPEN_UP)
      return lips[0] > teeth[0] && teeth[0] > jaw[0];
   if(am == OPEN_DOWN)
      return lips[0] < teeth[0] && teeth[0] < jaw[0];
   return false;
  }

//+------------------------------------------------------------------+
//| Helper: save chart screenshot                                    |
//+------------------------------------------------------------------+
void saveSignalScreenshot(string tag, datetime barTime)
  {
   ChartRedraw(ChartID());
   MqlDateTime dt;
   TimeToStruct(barTime, dt);

   string timePart = StringFormat("%04d%02d%02d_%02d%02d%02d",
                                  dt.year, dt.mon, dt.day,
                                  dt.hour, dt.min, dt.sec);
   string asset = Symbol();
   StringReplace(asset, ".pro", "");
   string period = EnumToString(Period());
   StringReplace(period, "PERIOD_", "");
   string fileName = StringFormat("%s_%s_%s_%s.gif",
                                  asset,
                                  period,
                                  tag,
                                  timePart);
// saved in MQL5\Files\
   if(!ChartScreenShot(ChartID(), fileName, ShotWidth, ShotHeight))
      Print("ChartScreenShot failed for file: ", fileName);
  }

//+------------------------------------------------------------------+
//| Draw divergent bar arrow objects                                 |
//+------------------------------------------------------------------+
void drawDivergentArrow(string tag, SingalDirection dir, datetime barTime)
  {
   string dirTag = (dir == SIGNAL_UP ? "BUY" : "SELL");
   string objName = StringFormat("%s_%s_%s_%I64d",
                                 tag, dirTag, _Symbol, (long)barTime);

   ENUM_OBJECT type = (dir == SIGNAL_UP ? OBJ_ARROW_BUY : OBJ_ARROW_SELL);
   int arrowShift = 250;
   double price = (dir == SIGNAL_UP ?
                   iLow(_Symbol, PERIOD_CURRENT, 1) - _Point * arrowShift :
                   iHigh(_Symbol, PERIOD_CURRENT, 1) + _Point * arrowShift);

   if(ObjectFind(ChartID(), objName) != -1)
      ObjectDelete(ChartID(), objName);

   if(!ObjectCreate(ChartID(), objName, type, 0, barTime, price))
     {
      Print("Failed to create divergent arrow object: ", objName);
      return;
     }

   ObjectSetInteger(ChartID(), objName, OBJPROP_COLOR,
                    (dir == SIGNAL_UP ? clrGreen : clrRed));
  }

//+------------------------------------------------------------------+
//| Draw fractal arrows                                              |
//+------------------------------------------------------------------+
void drawFractalArrow(SingalDirection dir, int shift, double price)
  {
   datetime t = iTime(_Symbol, PERIOD_CURRENT, shift);
   string dirTag = (dir == SIGNAL_UP ? "UpFractal" : "DownFractal");
   string objName = StringFormat("FR_%s_%s_%I64d",
                                 dirTag, _Symbol, (long)t);

   ENUM_OBJECT type = (dir == SIGNAL_UP ? OBJ_ARROW_BUY : OBJ_ARROW_SELL);

   if(ObjectFind(ChartID(), objName) != -1)
      ObjectDelete(ChartID(), objName);

   if(!ObjectCreate(ChartID(), objName, type, 0, t, price))
     {
      Print("Failed to create fractal arrow object: ", objName);
      return;
     }

   ObjectSetInteger(ChartID(), objName, OBJPROP_COLOR,
                    (dir == SIGNAL_UP ? clrGreen : clrRed));
  }

//+------------------------------------------------------------------+
