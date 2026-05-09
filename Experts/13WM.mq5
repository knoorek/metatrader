//+------------------------------------------------------------------+
//|                                DivergentBW_AngleJaw_Alerts_EA.mq5 |
//|   EA: Divergent BW bars + ATR angulation + Jaw filter            |
//|   - Divergent bar pending orders + screenshots + arrows + LR line|
//|   - Fractal/Jaw signals + screenshots + arrows                   |
//|   - Jaw trailing stop for BUY/SELL after first fractal outside   |
//+------------------------------------------------------------------+
#property strict

input int AliTrend   = 21;    // Min Alligator open mouth bars for Super Hammer
input int LRLength   = 13;    // Linear regression bars for Divergent Bar
input double LRRatio = 1.5;   // Linear regression angulation ratio
input bool TakeScreenshots = true;

enum Peak
  {
   MIN,
   MAX
  };

enum RegressionLine
  {
   CLOSE,
   TEETH,
   JAW
  };

//--- fixed angulation settings
const double   Lots        = 0.10;
const int      LR_Length   = LRLength;   // bars for linear regression         // StopLoss pips

//--- Alligator parameters (classic Bill Williams) - fixed
const int JawPeriod   = 13;
const int JawShift    = 8;
const int TeethPeriod = 8;
const int TeethShift  = 5;
const int LipsPeriod  = 5;
const int LipsShift   = 3;

//--- Super hammer parameters
const double maxWickSize = 0.33;
const double maxBodySize = 0.2;

//--- alert behavior - fixed (no sounds)
const bool UsePrintLog   = true;

//--- trading parameters - fixed
const int    Slippage    = 3;      // in points
const long   MagicNumber = 123456;

// screenshot settings
const int  ShotWidth  = 1920;
const int  ShotHeight = 768;

//--- indicator handles
int alligatorHandle = INVALID_HANDLE;
int fractHandle     = INVALID_HANDLE;   // Fractals

//--- last closed bar time processed
datetime lastBarTime = 0;

//--- cached fractal conditions (per bar)
bool g_buyTrailCondition  = false;
bool g_sellTrailCondition = false;
int  g_upFractShift       = -1;
int  g_downFractShift     = -1;

//+------------------------------------------------------------------+
//| Helper: save chart screenshot                                    |
//+------------------------------------------------------------------+
void SaveSignalScreenshot(const string tag, const datetime barTime)
  {
   if(!TakeScreenshots)
      return;

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
//| Helper: send trade request with common logging                   |
//+------------------------------------------------------------------+
bool SendTradeRequest(MqlTradeRequest &req, const string context)
  {
   MqlTradeResult res;
   ZeroMemory(res);

   if(!OrderSend(req, res))
     {
      Print(context, " OrderSend failed (no server response)");
      return false;
     }
   if(res.retcode != TRADE_RETCODE_DONE)
     {
      Print(context, " failed: ", res.retcode, " / ", res.comment);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   alligatorHandle = iAlligator(
                        _Symbol, PERIOD_CURRENT,
                        JawPeriod,   JawShift,
                        TeethPeriod, TeethShift,
                        LipsPeriod,  LipsShift,
                        MODE_SMMA, PRICE_MEDIAN
                     );
   if(alligatorHandle == INVALID_HANDLE)
     {
      Print("Failed to create Alligator handle");
      return(INIT_FAILED);
     }

   fractHandle = iFractals(_Symbol, PERIOD_CURRENT);
   if(fractHandle == INVALID_HANDLE)
     {
      Print("Failed to create Fractals handle");
      return(INIT_FAILED);
     }

   lastBarTime        = 0;
   g_buyTrailCondition  = false;
   g_sellTrailCondition = false;
   g_upFractShift       = -1;
   g_downFractShift     = -1;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(alligatorHandle != INVALID_HANDLE)
      IndicatorRelease(alligatorHandle);
   if(fractHandle     != INVALID_HANDLE)
      IndicatorRelease(fractHandle);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetAlligatorMinMax(const int shift, Peak peak)
  {
   if(alligatorHandle == INVALID_HANDLE)
      return 0.0;

   double jaw[1];
   double teeth[1];
   double lips[1];
   if(CopyBuffer(alligatorHandle, 0, shift, 1, jaw) != 1 ||
      CopyBuffer(alligatorHandle, 1, shift, 1, teeth) != 1 ||
      CopyBuffer(alligatorHandle, 2, shift, 1, lips) != 1)
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
double GetAlligator(const int shift, const int line)
  {
   if(alligatorHandle == INVALID_HANDLE)
      return 0.0;

   double buff[1];
   if(CopyBuffer(alligatorHandle, line, shift, 1, buff) != 1)
     {
      Print("ERROR: ", GetLastError());
      return 0.0;
     }

   return buff[0];

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsUpFractal(const int shift)
  {
   if(fractHandle == INVALID_HANDLE)
      return false;
   double buff[1];
   if(CopyBuffer(fractHandle, 0, shift, 1, buff) != 1)
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
   if(fractHandle == INVALID_HANDLE)
      return false;
   double buff[1];
   if(CopyBuffer(fractHandle, 1, shift, 1, buff) != 1)
     {
      Print("ERROR: ", GetLastError());
      return false;
     }
   return (buff[0] != 0.0 && buff[0] != EMPTY_VALUE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetRegressionY(const int shift, const RegressionLine regLine)
  {
   if(regLine == JAW)
      return GetAlligator(shift, 0);
   if(regLine == TEETH)
      return GetAlligator(shift, 1);
   else
      return iClose(_Symbol, PERIOD_CURRENT, shift);
  }

// Linear regression slope of Close over [shift ... shift+LR_Length-1]
double LinearRegressionSlope(const int shift, const int len, const RegressionLine regLine)
  {
   if(len < 2)
      return 0.0;
   if(shift + len >= Bars(_Symbol, PERIOD_CURRENT))
      return 0.0;

   double sumX  = 0.0;
   double sumY  = 0.0;
   double sumXY = 0.0;
   double sumX2 = 0.0;

   for(int i = 0; i < len; i++)
     {
      int barIndex = shift + len - 1 - i;
      double x = (double)i;
      double y = GetRegressionY(barIndex, regLine);

      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumX2 += x * x;
     }

   double n     = (double)len;
   double denom = n * sumX2 - sumX * sumX;
   if(denom == 0.0)
      return 0.0;

   return (n * sumXY - sumX * sumY) / denom; // price units per bar
  }

// Compute regression line endpoints for drawing
bool GetRegressionLinePoints(const int shift,
                             const int len,
                             const RegressionLine regLine,
                             datetime &tStart, double &yStart,
                             datetime &tEnd,   double &yEnd)
  {
   if(len < 2)
      return false;
   if(shift + len >= Bars(_Symbol, PERIOD_CURRENT))
      return false;

   double sumX  = 0.0;
   double sumY  = 0.0;
   double sumXY = 0.0;
   double sumX2 = 0.0;

   for(int i = 0; i < len; i++)
     {
      int barIndex = shift + len - 1 - i; // i=0 oldest
      double x = (double)i;
      double y = GetRegressionY(barIndex, regLine);

      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumX2 += x * x;
     }

   double n     = (double)len;
   double denom = n * sumX2 - sumX * sumX;
   if(denom == 0.0)
      return false;

   double slope     = (n * sumXY - sumX * sumY) / denom;
   double intercept = (sumY - slope * sumX) / n;

   int oldestIndex = shift + len - 1; // i=0 → oldest
   tStart = iTime(_Symbol, PERIOD_CURRENT, oldestIndex);
   tEnd   = iTime(_Symbol, PERIOD_CURRENT, shift);

   yStart = intercept;                   // at x=0
   yEnd   = intercept + slope * (len-1);// at x=len-1

   return true;
  }

// Sufficient angulation using precomputed ATR
bool HasAngulation(const int shift)
  {
   double closeSlope = LinearRegressionSlope(shift, LR_Length, CLOSE);
   double jawSlope = LinearRegressionSlope(shift, LR_Length, TEETH);

   if(closeSlope * jawSlope < 0)//same direction
      return false;
   if(MathAbs(closeSlope) < MathAbs(jawSlope))
      return false;

   double linesAngle = closeSlope / jawSlope;
   return (linesAngle >= LRRatio);
  }

// Jaw trend + price position filter (for divergent bar)
bool AlligatorJawFilter(const int shift, const bool bullish)
  {
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);

   if(bullish)
     {
      double jawCur  = GetAlligatorMinMax(shift, MIN);
      double jawPrev = GetAlligatorMinMax(shift + 1, MIN);
      if(jawCur == 0.0 || jawPrev == 0.0)
         return false;
      return (close < jawCur && jawCur < jawPrev);
     }
   else
     {
      double jawCur  = GetAlligatorMinMax(shift, MAX);
      double jawPrev = GetAlligatorMinMax(shift + 1, MAX);
      if(jawCur == 0.0 || jawPrev == 0.0)
         return false;
      return (close > jawCur && jawCur > jawPrev);
     }
  }

//+------------------------------------------------------------------+
//| Fractal / Jaw conditions                                         |
//+------------------------------------------------------------------+
bool LastUpFractalIsFirstAboveJaw(const int fromShift, int &fractShift)
  {
   fractShift = -1;
   if(fractHandle == INVALID_HANDLE || alligatorHandle == INVALID_HANDLE)
      return false;

   int start = MathMax(fromShift, 3);
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

   double jaw0 = GetAlligatorMinMax(f0, MAX);
   if(jaw0 == 0.0 || iHigh(_Symbol, PERIOD_CURRENT, f0) <= jaw0)
      return false;

   double jaw1 = GetAlligatorMinMax(f1, MAX);
   if(jaw1 == 0.0)
      return false;

   if(iHigh(_Symbol, PERIOD_CURRENT, f1) <= jaw1)
     {
      fractShift = f0;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool LastDownFractalIsFirstBelowJaw(const int fromShift, int &fractShift)
  {
   fractShift = -1;
   if(fractHandle == INVALID_HANDLE || alligatorHandle == INVALID_HANDLE)
      return false;

   int start = MathMax(fromShift, 3);
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

   double jaw0 = GetAlligatorMinMax(f0, MIN);
   if(jaw0 == 0.0 || iLow(_Symbol, PERIOD_CURRENT, f0) >= jaw0)
      return false;

   double jaw1 = GetAlligatorMinMax(f1, MIN);
   if(jaw1 == 0.0)
      return false;

   if(iLow(_Symbol, PERIOD_CURRENT, f1) >= jaw1)
     {
      fractShift = f0;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int HasAlligatorTrend(const int shift, const bool bullish)
  {
   if(alligatorHandle == INVALID_HANDLE)
      return false;
   if(AliTrend == 0)
      if(bullish)
         return -1;
      else
         return 1;

   double jaw[];
   double teeth[];

   if(CopyBuffer(alligatorHandle, 0, shift, AliTrend, jaw) != AliTrend ||
      CopyBuffer(alligatorHandle, 1, shift, AliTrend, teeth) != AliTrend)
     {
      Print("ERROR: ", GetLastError());
      return false;
     }

   int mouthOpenUp = 0;
   int mouthOpenDown = 0;
   for(int i = 0; i < AliTrend; i++)
     {
      if(teeth[i] > jaw[i])
         mouthOpenUp++;
      if(teeth[i] < jaw[i])
         mouthOpenDown++;
      if(mouthOpenDown > 0 && mouthOpenUp > 0)
        {
         return false;
        }
     }
   if(bullish && mouthOpenUp > 0)
      return 0;
   if(!bullish && mouthOpenDown > 0)
      return 0;
   if(mouthOpenUp)
      return 1;
   if(mouthOpenDown)
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//| Divergent bar detection                                          |
//+------------------------------------------------------------------+
bool IsBullishDivergentBar(const int shift)
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
   if(!AlligatorJawFilter(shift, true))
      return false;
   if(!HasAngulation(shift))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBullishSuperHammerBar(const int shift)
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
   if(!(wick / barSize <= maxWickSize && body / barSize <= maxBodySize))
      return false;
   if(!AlligatorJawFilter(shift, true))
      return false;
   if(!(HasAlligatorTrend(shift, true) == -1))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBearishDivergentBar(const int shift)
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
   if(!AlligatorJawFilter(shift, false))
      return false;
   if(!HasAngulation(shift))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBearishSuperHammerBar(const int shift)
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
   if(!(wick / barSize <= maxWickSize && body / barSize <= maxBodySize))
      return false;
   if(!AlligatorJawFilter(shift, false))
      return false;
   if(!(HasAlligatorTrend(shift, false) == 1))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int DivergentBarSignal(const int shift)
  {
   if(IsBullishDivergentBar(shift))
      return  1;
   if(IsBearishDivergentBar(shift))
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SuperHammerSignal(const int shift)
  {
   if(IsBullishSuperHammerBar(shift))
      return  1;
   if(IsBearishSuperHammerBar(shift))
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//| Position helpers                                                 |
//+------------------------------------------------------------------+
bool HasOpenPosition(const ENUM_POSITION_TYPE posType)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long   mag = PositionGetInteger(POSITION_MAGIC);
      ENUM_POSITION_TYPE t = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(sym == _Symbol && mag == MagicNumber && t == posType)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasPendingOrders(const ENUM_ORDER_TYPE orderType)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket))
         continue;

      string sym = OrderGetString(ORDER_SYMBOL);
      long   mag = OrderGetInteger(ORDER_MAGIC);
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(sym == _Symbol && mag == MagicNumber && t == orderType)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Manage pending stop orders                                       |
//+------------------------------------------------------------------+
void ManagePendingOrders()
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;

      string sym = OrderGetString(ORDER_SYMBOL);
      long   mag = OrderGetInteger(ORDER_MAGIC);
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      double sl = OrderGetDouble(ORDER_SL);
      if(sym != _Symbol || mag != MagicNumber || sl <= 0.0)
         continue;

      bool shouldDelete = false;

      if(type == ORDER_TYPE_BUY_STOP && bid <= sl)
         shouldDelete = true;
      else
         if(type == ORDER_TYPE_SELL_STOP && ask >= sl)
            shouldDelete = true;

      if(shouldDelete)
        {
         MqlTradeRequest req;
         ZeroMemory(req);
         req.action = TRADE_ACTION_REMOVE;
         req.order  = ticket;
         req.symbol = _Symbol;
         SendTradeRequest(req, "RemovePending");
        }
     }
  }

//+------------------------------------------------------------------+
//| Manage trailing stop using Jaw                                   |
//+------------------------------------------------------------------+
void ManageTrailingStops(double jaw0)
  {
   if(jaw0 <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   int    stopLevelPoints = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point           = _Point;
   int    digits          = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minDist         = stopLevelPoints > 0 ? stopLevelPoints * point : 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long   mag = PositionGetInteger(POSITION_MAGIC);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(sym != _Symbol || mag != MagicNumber)
         continue;

      double curSL = PositionGetDouble(POSITION_SL);
      double newSL = curSL;

      if(type == POSITION_TYPE_BUY && g_buyTrailCondition)
        {
         newSL = jaw0;
         if(newSL >= bid)
            newSL = bid - 2 * point;
         if(stopLevelPoints > 0 && (bid - newSL) < minDist)
            newSL = bid - minDist;
         if(newSL <= 0.0)
            continue;
         if(curSL > 0.0 && newSL <= curSL)
            continue;
        }
      else
         if(type == POSITION_TYPE_SELL && g_sellTrailCondition)
           {
            newSL = jaw0;
            if(newSL <= ask)
               newSL = ask + 2 * point;
            if(stopLevelPoints > 0 && (newSL - ask) < minDist)
               newSL = ask + minDist;
            if(newSL <= 0.0)
               continue;
            if(curSL > 0.0 && newSL >= curSL)
               continue;
           }
         else
            continue;

      MqlTradeRequest req;
      ZeroMemory(req);
      req.action   = TRADE_ACTION_SLTP;
      req.symbol   = _Symbol;
      req.position = ticket;
      req.sl       = NormalizeDouble(newSL, digits);
      req.tp       = PositionGetDouble(POSITION_TP);

      SendTradeRequest(req, "TrailSL");
     }
  }

//+------------------------------------------------------------------+
//| Place pending order for divergent bar                            |
//+------------------------------------------------------------------+
void PlaceOrderForDivergent(const int dbSignal, int tpPips)
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;

   int    stopLevelPoints = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point           = _Point;
   int    digits          = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   MqlTradeRequest req;
   ZeroMemory(req);

   req.action    = TRADE_ACTION_PENDING;
   req.symbol    = _Symbol;
   req.magic     = MagicNumber;
   req.deviation = Slippage;
   req.volume    = Lots;

   double entryPrice, sl, tp = 0.0;

   if(dbSignal == 1) // BULLISH → BUY_STOP
     {
      if(HasOpenPosition(POSITION_TYPE_BUY) || HasPendingOrders(ORDER_TYPE_BUY_STOP))
         return;

      req.type = ORDER_TYPE_BUY_STOP;

      entryPrice = iHigh(_Symbol, PERIOD_CURRENT, 1) + point;
      if(entryPrice <= ask)
         entryPrice = ask + point;

      if(tpPips > 0)
         tp = entryPrice + tpPips * point;

      if(stopLevelPoints > 0)
        {
         double minDist = stopLevelPoints * point;
         if(entryPrice - ask < minDist)
            entryPrice = ask + minDist;
        }

      sl = iLow(_Symbol, PERIOD_CURRENT, 1);
      if(sl >= entryPrice)
         sl = entryPrice - 2 * point;

      if(stopLevelPoints > 0)
        {
         double minDist = stopLevelPoints * point;
         if(entryPrice - sl < minDist)
            sl = entryPrice - minDist;
        }
     }
   else
      if(dbSignal == -1) // BEARISH → SELL_STOP
        {
         if(HasOpenPosition(POSITION_TYPE_SELL) || HasPendingOrders(ORDER_TYPE_SELL_STOP))
            return;

         req.type = ORDER_TYPE_SELL_STOP;

         entryPrice = iLow(_Symbol, PERIOD_CURRENT, 1) - point;
         if(entryPrice >= bid)
            entryPrice = bid - point;

         if(tpPips > 0)
            tp = entryPrice - tpPips * point;

         if(stopLevelPoints > 0)
           {
            double minDist = stopLevelPoints * point;
            if(bid - entryPrice < minDist)
               entryPrice = bid - minDist;
           }

         sl = iHigh(_Symbol, PERIOD_CURRENT, 1);
         if(sl <= entryPrice)
            sl = entryPrice + 2 * point;

         if(stopLevelPoints > 0)
           {
            double minDist = stopLevelPoints * point;
            if(sl - entryPrice < minDist)
               sl = entryPrice + minDist;
           }
        }
      else
         return;

   req.price = NormalizeDouble(entryPrice, digits);
   req.sl    = NormalizeDouble(sl, digits);
   req.tp    = NormalizeDouble(tp, digits);

   SendTradeRequest(req, "PlacePending");
  }

//+------------------------------------------------------------------+
//| Draw divergent bar arrow objects                                 |
//+------------------------------------------------------------------+
void DrawDivergentArrow(string tag, const int dbSignal, const datetime barTime)
  {
   string dirTag = (dbSignal == 1 ? "BUY" : "SELL");
   string objName = StringFormat("%s_%s_%s_%I64d",
                                 tag, dirTag, _Symbol, (long)barTime);

   ENUM_OBJECT type = (dbSignal == 1 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL);
   double price = (dbSignal == 1 ? iHigh(_Symbol, PERIOD_CURRENT, 1) : iLow(_Symbol, PERIOD_CURRENT, 1));

   if(ObjectFind(ChartID(), objName) != -1)
      ObjectDelete(ChartID(), objName);

   if(!ObjectCreate(ChartID(), objName, type, 0, barTime, price))
     {
      Print("Failed to create divergent arrow object: ", objName);
      return;
     }

   ObjectSetInteger(ChartID(), objName, OBJPROP_COLOR,
                    (dbSignal == 1 ? clrGreen : clrRed));
  }

//+------------------------------------------------------------------+
//| Draw regression line for divergent bar                           |
//+------------------------------------------------------------------+
void DrawRegressionLineForDivergent(const datetime barTime, const RegressionLine regLine, const long clr)
  {
   datetime t1, t2;
   double   y1, y2;
   if(!GetRegressionLinePoints(1, LR_Length, regLine, t1, y1, t2, y2))
      return;

   string objName = StringFormat("LR_DB_%s_%s_%I64d", _Symbol, EnumToString(regLine), (long)barTime);

   if(ObjectFind(ChartID(), objName) != -1)
      ObjectDelete(ChartID(), objName);

   if(!ObjectCreate(ChartID(), objName, OBJ_TREND, 0, t1, y1, t2, y2))
     {
      Print("Failed to create regression line object: ", objName);
      return;
     }

   ObjectSetInteger(ChartID(), objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(ChartID(), objName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(ChartID(), objName, OBJPROP_WIDTH, 3);
  }

//+------------------------------------------------------------------+
//| Draw fractal arrows                                              |
//+------------------------------------------------------------------+
void DrawFractalArrow(const bool bullishFractal, const int shift)
  {
   datetime t = iTime(_Symbol, PERIOD_CURRENT, shift);
   double price = bullishFractal ? iLow(_Symbol, PERIOD_CURRENT, shift) : iHigh(_Symbol, PERIOD_CURRENT, shift);
   string dirTag = bullishFractal ? "UpFractal" : "DownFractal";
   string objName = StringFormat("FR_%s_%s_%I64d",
                                 dirTag, _Symbol, (long)t);

   ENUM_OBJECT type = bullishFractal ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;

   if(ObjectFind(ChartID(), objName) != -1)
      ObjectDelete(ChartID(), objName);

   if(!ObjectCreate(ChartID(), objName, type, 0, t, price))
     {
      Print("Failed to create fractal arrow object: ", objName);
      return;
     }

   ObjectSetInteger(ChartID(), objName, OBJPROP_COLOR,
                    (bullishFractal ? clrGreen : clrRed));
  }

//+------------------------------------------------------------------+
//| OnTick – manage pending & trailing, then new bar signals         |
//+------------------------------------------------------------------+
void OnTick()
  {
// manage existing pending orders every tick
   ManagePendingOrders();

// manage trailing stops using current Jaw and cached fractal flags
   double alligatorLine = GetAlligator(0, 1);
   ManageTrailingStops(alligatorLine);

   int minBars = MathMax(LR_Length, JawPeriod + JawShift) + 5;
   if(Bars(_Symbol, PERIOD_CURRENT) <= minBars)
      return;

   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 1);   // last closed bar

   if(barTime == lastBarTime)
      return; // no new bar

// --- per-bar: recompute fractal trail conditions (used both for trail + alerts) ---
   g_buyTrailCondition  = LastUpFractalIsFirstAboveJaw(1, g_upFractShift);
   g_sellTrailCondition = LastDownFractalIsFirstBelowJaw(1, g_downFractShift);
   int superHammer = SuperHammerSignal(1);

// 1) Divergent bar signal (and orders)
   int dbSignal = DivergentBarSignal(1);
   if(dbSignal != 0)
     {
      string dir = (dbSignal == 1 ? "UP" : "DOWN");
      string msg = StringFormat("Divergent bar (%s) on %s %s at bar time %s",
                                dir, _Symbol, EnumToString(Period()),
                                TimeToString(barTime, TIME_DATE|TIME_SECONDS));

      DrawDivergentArrow("DB", dbSignal, barTime);
      DrawRegressionLineForDivergent(barTime, CLOSE, clrOrange);
      DrawRegressionLineForDivergent(barTime, TEETH, clrDarkOrange);
      SaveSignalScreenshot("DB_" + dir, barTime);
      PlaceOrderForDivergent(dbSignal, 0);
      if(UsePrintLog)
         Print(msg);
     }

// 1a) Super hammer
   if(superHammer != 0)
     {
      string dir = (superHammer == 1 ? "UP" : "DOWN");
      string msg = StringFormat("Super hammer bar (%s) on %s %s at bar time %s",
                                dir, _Symbol, EnumToString(Period()),
                                TimeToString(barTime, TIME_DATE|TIME_SECONDS));

      DrawDivergentArrow("SH", superHammer, barTime);
      SaveSignalScreenshot("SH_" + dir, barTime);
      if(UsePrintLog)
         Print(msg);
     }

// 3) Up fractal signal (only if no divergent message this bar)
   if(g_buyTrailCondition && g_upFractShift >= 0)
     {
      string msg = StringFormat(
                      "UP FRACTAL: last up fractal is FIRST above Jaw on %s %s (fractal bar time %s)",
                      _Symbol, EnumToString(Period()),
                      TimeToString(iTime(_Symbol, PERIOD_CURRENT, g_upFractShift), TIME_DATE|TIME_SECONDS)
                   );

      DrawFractalArrow(true, g_upFractShift);
      SaveSignalScreenshot("FAJ", barTime);
      if(UsePrintLog)
         Print(msg);
     }

// 3) Down fractal signal (only if no other message this bar)
   if(g_sellTrailCondition && g_downFractShift >= 0)
     {
      string msg = StringFormat(
                      "DOWN FRACTAL: last down fractal is FIRST below Jaw on %s %s (fractal bar time %s)",
                      _Symbol, EnumToString(Period()),
                      TimeToString(iTime(_Symbol, PERIOD_CURRENT, g_downFractShift), TIME_DATE|TIME_SECONDS)
                   );

      DrawFractalArrow(false, g_downFractShift);
      SaveSignalScreenshot("FBJ", barTime);
      if(UsePrintLog)
         Print(msg);
     }

   lastBarTime = barTime;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
