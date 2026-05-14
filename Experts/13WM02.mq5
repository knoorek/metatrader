//+------------------------------------------------------------------+
//|                                                     13WM02.mq5   |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Controls\Button.mqh>

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#define BTN_BUY_NAME "Btn Buy"
#define BTN_SELL_NAME "Btn Sell"
#define BTN_CLOSE_NAME "Btn Close"
#define LBL_SIGNALS_COUNT "Lbl Signals Count"

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

enum SignalType
  {
   DB_UP,
   DB_DOWN,
   SH_UP,
   SH_DOWN,
   DB2_UP,
   DB2_DOWN,
   FJ_UP,
   FJ_DOWN,
   FOM_UP,
   FOM_DOWN
  };

input bool DB = true;   //report divergent bar
input bool DB2 = true;  //report two divergent bars
input bool SH = true;   //report super hammer
input bool JF = true;   //report first fractal above/below jaw
input bool OMF = true;  //report first fractal above/below open mouth
input bool MTB = false; //add manual trading buttons (strategy testing)

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

//--- last closed bar time processed
datetime LastBarTime;
//--- fractal above/below jaw
datetime LastFAJBarDateTime;
datetime LastFBJBarDateTime;
//--- fractal above/below mouth
datetime LastFAOMBarDateTime;
datetime LastFBOMJBarDateTime;

datetime InitTime;
int SignalsCount = 0;

CButton BtnBuy;
CButton BtnSell;
CButton BtnClose;
CTrade Trade;

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

   if(MTB)
     {
      BtnBuy.Create(0, BTN_BUY_NAME, 0, 50, 50, 200, 80);
      BtnBuy.Text("Buy");
      BtnBuy.Color(clrWhite);
      BtnBuy.ColorBackground(clrGreen);

      BtnSell.Create(0, BTN_SELL_NAME, 0, 50, 81, 200, 111);
      BtnSell.Text("Sell");
      BtnSell.Color(clrWhite);
      BtnSell.ColorBackground(clrRed);

      BtnClose.Create(0, BTN_CLOSE_NAME, 0, 50, 112, 200, 142);
      BtnClose.Text("Close");
      BtnClose.Color(clrWhite);
      BtnClose.ColorBackground(clrBlack);
     }

   InitTime = TimeCurrent();
   if(ObjectCreate(ChartID(), LBL_SIGNALS_COUNT, OBJ_LABEL, 0, 0, 0))
     {
      ObjectSetInteger(ChartID(), LBL_SIGNALS_COUNT, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(ChartID(), LBL_SIGNALS_COUNT, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(ChartID(), LBL_SIGNALS_COUNT, OBJPROP_XDISTANCE, 30);
      ObjectSetInteger(ChartID(), LBL_SIGNALS_COUNT, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(ChartID(), LBL_SIGNALS_COUNT, OBJPROP_COLOR, clrBlack);
      ObjectSetString(ChartID(), LBL_SIGNALS_COUNT, OBJPROP_FONT, "Verdana");
      ObjectSetInteger(ChartID(), LBL_SIGNALS_COUNT, OBJPROP_FONTSIZE, 8);
     }
   else
     {
      Print("Failed to create initTime object");
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
   if(MTB)
     {
      BtnBuy.Destroy(reason);
      BtnSell.Destroy(reason);
      BtnClose.Destroy(reason);
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   handleButtons();

   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(barTime == LastBarTime)
      return;

   if(SH && isSuperHammerUp(1))
      handleSignal(SH_UP, iTime(_Symbol, PERIOD_CURRENT, 1));
   else
      if(DB && isDivergentBarUp(1))
         handleSignal(DB_UP, iTime(_Symbol, PERIOD_CURRENT, 1));
      else
         if(DB2 && isTwoBarDivergenceUp(1))
            handleSignal(DB2_UP, iTime(_Symbol, PERIOD_CURRENT, 1));

   if(SH && isSuperHammerDown(1))
      handleSignal(SH_DOWN, iTime(_Symbol, PERIOD_CURRENT, 1));
   else
      if(DB && isDivergentBarDown(1))
         handleSignal(DB_DOWN, iTime(_Symbol, PERIOD_CURRENT, 1));
      else
         if(DB2 && isTwoBarDivergenceDown(1))
            handleSignal(DB2_DOWN, iTime(_Symbol, PERIOD_CURRENT, 1));

   if(JF && isFirstFractalAboveJaw(3))
      handleSignal(FJ_UP, LastFAJBarDateTime);
   if(JF && isFirstFractalBelowJaw(1))
      handleSignal(FJ_DOWN, LastFBJBarDateTime);
   if(OMF && isFirstFractalAboveMouth(3))
      handleSignal(FOM_UP, LastFAOMBarDateTime);
   if(OMF && isFirstFractalBelowMouth(3))
      handleSignal(FOM_DOWN, LastFBOMJBarDateTime);

   LastBarTime = barTime;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void handleButtons()
  {
   if(BtnBuy.Pressed())
     {
      Print("BUY pressed...");
      Trade.Buy(0.1);
      BtnBuy.Pressed(false);
     }
   if(BtnSell.Pressed())
     {
      Print("SELL pressed...");
      Trade.Sell(0.1);
      BtnSell.Pressed(false);
     }
   if(BtnClose.Pressed())
     {
      Print("CLOSE pressed...");
      for(int i = 0; i < PositionsTotal(); i++)
        {
         ulong ticket = PositionGetTicket(i);
         Trade.PositionClose(ticket);
        }
      BtnClose.Pressed(false);
     }
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
   if(!filterWithAlligator(shift, BELOW_ALLIGATOR, curHigh))
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
   if(!filterWithAlligator(shift, ABOVE_ALLIGATOR, curLow))
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
   if(!filterWithAlligator(shift, BELOW_ALLIGATOR, twoBarsHigh))
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
   if(!filterWithAlligator(shift, ABOVE_ALLIGATOR, twoBarsLow))
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
   if(!filterWithAlligator(shift, BELOW_ALLIGATOR, curHigh))
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
   if(!filterWithAlligator(shift, ABOVE_ALLIGATOR, curLow))
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
bool filterWithAlligator(int shift, AlligatorFilter af, double price)
  {
   if(af == BELOW_ALLIGATOR)
     {
      double jawCur = getAlligatorMinMax(shift, MIN);
      double jawPrev = getAlligatorMinMax(shift + 1, MIN);
      if(jawCur == 0.0 || jawPrev == 0.0)
         return false;
      return (price < jawCur && jawCur < jawPrev);
     }
   if(af == ABOVE_ALLIGATOR)
     {
      double jawCur = getAlligatorMinMax(shift, MAX);
      double jawPrev = getAlligatorMinMax(shift + 1, MAX);
      if(jawCur == 0.0 || jawPrev == 0.0)
         return false;
      return (price > jawCur && jawCur > jawPrev);
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
bool isAlligatorMouthOpen(int shift, AlligatorMouth am)
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
//|                                                                  |
//+------------------------------------------------------------------+
void handleSignal(SignalType sig, datetime barTime)
  {
   string msg = StringFormat("%s on: %s %s at: %s",
                             EnumToString(sig),
                             _Symbol,
                             EnumToString(Period()),
                             TimeToString(barTime, TIME_DATE|TIME_SECONDS));
   drawArrow(sig, barTime);
   ++SignalsCount;
   ObjectSetString(ChartID(),
                   LBL_SIGNALS_COUNT,
                   OBJPROP_TEXT,
                   StringFormat("Signals from %s: %s",
                                TimeToString(InitTime, TIME_DATE|TIME_SECONDS),
                                IntegerToString(SignalsCount)));
   saveSignalScreenshot(sig, barTime);
   Print(msg);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void drawArrow(SignalType sig, datetime barTime)
  {
   int shift = barFromTime(barTime);
   double price = (isUpSignal(sig) ?
                   iLow(_Symbol, PERIOD_CURRENT, shift) - _Point :
                   iHigh(_Symbol, PERIOD_CURRENT, shift) + _Point);

   string objName = StringFormat("%s_%I64d", EnumToString(sig), (long)barTime);
   if(ObjectFind(ChartID(), objName) != -1)
      ObjectDelete(ChartID(), objName);

   ENUM_OBJECT type = (isUpSignal(sig) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL);
   if(!ObjectCreate(ChartID(), objName, type, 0, barTime, price))
     {
      Print("Failed to create arrow object: ", objName);
      return;
     }

   ObjectSetInteger(ChartID(), objName, OBJPROP_COLOR,
                    (isUpSignal(sig) ? clrGreen : clrRed));
  }

//+------------------------------------------------------------------+
//| Helper: save chart screenshot                                    |
//+------------------------------------------------------------------+
void saveSignalScreenshot(SignalType sig, datetime barTime)
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
                                  EnumToString(sig),
                                  timePart);
// saved in MQL5\Files\
   if(!ChartScreenShot(ChartID(), fileName, ShotWidth, ShotHeight))
      Print("ChartScreenShot failed for file: ", fileName);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int barFromTime(datetime barTime)
  {
   int shift = -1;
   for(int i = 1; i <= Bars(_Symbol, PERIOD_CURRENT); i++)
      if(barTime == iTime(_Symbol, PERIOD_CURRENT, i))
        {
         shift = i;
         break;
        }
   if(shift == -1)
      Print("Illegal state, bar for barTime not found");
   return shift;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isUpSignal(SignalType sig)
  {
   return sig == DB_UP ||
          sig == DB2_UP ||
          sig == SH_UP ||
          sig == FJ_UP ||
          sig == FOM_UP;
  }
//+------------------------------------------------------------------+
