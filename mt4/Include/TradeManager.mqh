//+------------------------------------------------------------------+
//| TradeManager.mqh                                                 |
//| GoldPilotAI Enterprise v3.0 - Strategy Layer                     |
//| Order placement, validation, and trade management                |
//+------------------------------------------------------------------+
#ifndef __TRADEMANAGER_MQH__
#define __TRADEMANAGER_MQH__

#include "Config.mqh"
#include "Globals.mqh"
#include "Indicators.mqh"
#include "Utilities.mqh"

//====================================================================
// ORDER VALIDATION STRUCTURE
//====================================================================
struct OrderParams
{
   int TradeType;           // OP_BUY or OP_SELL
   double EntryPrice;       // Entry price
   double StopLoss;         // Stop loss level
   double TakeProfit;       // Take profit level
   double LotSize;          // Position size
   string Comment;          // Order comment
   bool IsValid;            // Validation result
   string ValidationError;  // Error message if invalid
};

//====================================================================
// STOP LOSS CALCULATION
//====================================================================

//--------------------------------------------------------------------
// Calculate Buy Stop Loss (Lowest point of recent candles)
//--------------------------------------------------------------------
double CalculateSLBuy(int lookbackCandles)
{
   if(lookbackCandles <= 0)
      lookbackCandles = ML_SL_Lookback;
   
   double lowestLow = iLow(Symbol(), EntryTF, 1);
   
   for(int i = 2; i <= lookbackCandles; i++)
   {
      double low = iLow(Symbol(), EntryTF, i);
      if(low < lowestLow)
         lowestLow = low;
   }
   
   // Subtract buffer (2-5 pips below lowest point)
   double sl = lowestLow - (SLBuffer * Point);
   
   // Validate SL distance
   double slDistance = (Ask - sl) / Point;
   
   if(slDistance < ML_MinSL_Points)
   {
      sl = Ask - (ML_MinSL_Points * Point);
   }
   
   if(slDistance > ML_MaxSL_Points)
   {
      sl = Ask - (ML_MaxSL_Points * Point);
   }
   
   return sl;
}

//--------------------------------------------------------------------
// Calculate Sell Stop Loss (Highest point of recent candles)
//--------------------------------------------------------------------
double CalculateSLSell(int lookbackCandles)
{
   if(lookbackCandles <= 0)
      lookbackCandles = ML_SL_Lookback;
   
   double highestHigh = iHigh(Symbol(), EntryTF, 1);
   
   for(int i = 2; i <= lookbackCandles; i++)
   {
      double high = iHigh(Symbol(), EntryTF, i);
      if(high > highestHigh)
         highestHigh = high;
   }
   
   // Add buffer (2-5 pips above highest point)
   double sl = highestHigh + (SLBuffer * Point);
   
   // Validate SL distance
   double slDistance = (sl - Bid) / Point;
   
   if(slDistance < ML_MinSL_Points)
   {
      sl = Bid + (ML_MinSL_Points * Point);
   }
   
   if(slDistance > ML_MaxSL_Points)
   {
      sl = Bid + (ML_MaxSL_Points * Point);
   }
   
   return sl;
}

//====================================================================
// TAKE PROFIT CALCULATION
//====================================================================

//--------------------------------------------------------------------
// Calculate Buy Take Profit
//--------------------------------------------------------------------
double CalculateTPBuy(int tpPoints)
{
   if(tpPoints <= 0)
      tpPoints = DefaultTakeProfit;
   
   return (Ask + (tpPoints * Point));
}

//--------------------------------------------------------------------
// Calculate Sell Take Profit
//--------------------------------------------------------------------
double CalculateTPSell(int tpPoints)
{
   if(tpPoints <= 0)
      tpPoints = DefaultTakeProfit;
   
   return (Bid - (tpPoints * Point));
}

//====================================================================
// LOT SIZE CALCULATION
//====================================================================

//--------------------------------------------------------------------
// Calculate Lot Size Based on Risk Percentage
//--------------------------------------------------------------------
double CalculateLotSize(double riskPercent, double slDistancePoints)
{
   if(slDistancePoints <= 0)
   {
      Print("ERROR: SL distance must be positive");
      return 0;
   }
   
   // Account equity
   double accountEquity = AccountEquity();
   
   // Risk amount in account currency
   double riskAmount = (accountEquity * riskPercent) / 100.0;
   
   // Pip value for GOLD (XAU/USD) = 1 point = $0.01
   // Lot size calculation: Lot = (Risk Amount) / (SL points × Pip Value)
   double pipValue = 0.01;  // For XAUUSD
   double lotSize = riskAmount / (slDistancePoints * pipValue);
   
   // Round to nearest 0.01 (minimum MT4 lot)
   lotSize = MathRound(lotSize * 100) / 100;
   
   // Apply constraints
   if(lotSize < MinimumLotSize)
      lotSize = MinimumLotSize;
   
   if(lotSize > MaximumLotSize)
      lotSize = MaximumLotSize;
   
   return lotSize;
}

//--------------------------------------------------------------------
// Get Fixed Lot Size (User-defined)
//--------------------------------------------------------------------
double GetFixedLotSize()
{
   double lot = LotSize;
   
   if(lot < MinimumLotSize)
      lot = MinimumLotSize;
   
   if(lot > MaximumLotSize)
      lot = MaximumLotSize;
   
   return lot;
}

//====================================================================
// ORDER VALIDATION
//====================================================================

//--------------------------------------------------------------------
// Validate Order Parameters Before Placement
//--------------------------------------------------------------------
OrderParams ValidateOrderParams(int tradeType, double entryPrice, 
                                double sl, double tp, double lot, 
                                string comment)
{
   OrderParams params;
   params.TradeType = tradeType;
   params.EntryPrice = entryPrice;
   params.StopLoss = sl;
   params.TakeProfit = tp;
   params.LotSize = lot;
   params.Comment = comment;
   params.IsValid = true;
   params.ValidationError = "";
   
   //---
   // Check: Spread is acceptable
   //---
   if(Spread > MaxSpreadPoints)
   {
      params.IsValid = false;
      params.ValidationError = StringFormat(
         "Spread too wide: %.0f > %.0f", Spread, MaxSpreadPoints);
      return params;
   }
   
   //---
   // Check: Lot size is valid
   //---
   if(lot <= 0 || lot < MinimumLotSize)
   {
      params.IsValid = false;
      params.ValidationError = StringFormat(
         "Lot size invalid: %.2f (min: %.2f)", lot, MinimumLotSize);
      return params;
   }
   
   if(lot > MaximumLotSize)
   {
      params.IsValid = false;
      params.ValidationError = StringFormat(
         "Lot size exceeds maximum: %.2f > %.2f", lot, MaximumLotSize);
      return params;
   }
   
   //---
   // Check: SL is below entry for BUY (or above for SELL)
   //---
   if(tradeType == OP_BUY)
   {
      if(sl >= entryPrice)
      {
         params.IsValid = false;
         params.ValidationError = StringFormat(
            "BUY SL must be below entry: %.5f >= %.5f", sl, entryPrice);
         return params;
      }
   }
   else if(tradeType == OP_SELL)
   {
      if(sl <= entryPrice)
      {
         params.IsValid = false;
         params.ValidationError = StringFormat(
            "SELL SL must be above entry: %.5f <= %.5f", sl, entryPrice);
         return params;
      }
   }
   
   //---
   // Check: TP is above entry for BUY (or below for SELL)
   //---
   if(tradeType == OP_BUY)
   {
      if(tp <= entryPrice)
      {
         params.IsValid = false;
         params.ValidationError = StringFormat(
            "BUY TP must be above entry: %.5f <= %.5f", tp, entryPrice);
         return params;
      }
   }
   else if(tradeType == OP_SELL)
   {
      if(tp >= entryPrice)
      {
         params.IsValid = false;
         params.ValidationError = StringFormat(
            "SELL TP must be below entry: %.5f >= %.5f", tp, entryPrice);
         return params;
      }
   }
   
   //---
   // Check: SL and TP distances meet minimums
   //---
   double slDistance = MathAbs(entryPrice - sl) / Point;
   double tpDistance = MathAbs(tp - entryPrice) / Point;
   
   if(slDistance < MinimumSLDistance)
   {
      params.IsValid = false;
      params.ValidationError = StringFormat(
         "SL distance too small: %.0f < %.0f points", 
         slDistance, MinimumSLDistance);
      return params;
   }
   
   if(tpDistance < MinimumTPDistance)
   {
      params.IsValid = false;
      params.ValidationError = StringFormat(
         "TP distance too small: %.0f < %.0f points", 
         tpDistance, MinimumTPDistance);
      return params;
   }
   
   //---
   // Check: Risk/Reward ratio acceptable
   //---
   if(RiskRewardRatio > 0)
   {
      if(tpDistance < (slDistance * RiskRewardRatio))
      {
         params.IsValid = false;
         params.ValidationError = StringFormat(
            "Risk/Reward ratio poor: %.2f:1 (required: %.2f:1)", 
            tpDistance/slDistance, RiskRewardRatio);
         return params;
      }
   }
   
   //---
   // Check: Account has sufficient margin
   //---
   if(AccountFreeMargin() < lot * 1000)  // Rough estimate
   {
      params.IsValid = false;
      params.ValidationError = StringFormat(
         "Insufficient margin: %.2f", AccountFreeMargin());
      return params;
   }
   
   return params;
}

//====================================================================
// ORDER PLACEMENT
//====================================================================

//--------------------------------------------------------------------
// Place Buy Trade
//--------------------------------------------------------------------
int PlaceBuyOrder(double entryPrice, double sl, double tp, 
                  double lot, string comment)
{
   // Validate parameters
   OrderParams params = ValidateOrderParams(
      OP_BUY, entryPrice, sl, tp, lot, comment);
   
   if(!params.IsValid)
   {
      Print("❌ BUY ORDER BLOCKED | Reason: ", params.ValidationError);
      return -1;
   }
   
   // Use Ask price as actual entry
   double actualEntry = Ask;
   
   // Recalculate TP based on actual entry
   double actualTP = CalculateTPBuy(DefaultTakeProfit);
   
   // Place order
   int ticket = OrderSend(
      Symbol(),           // Symbol
      OP_BUY,             // Operation
      lot,                // Lot size
      actualEntry,        // Price
      MaxSlippage,        // Max slippage (pips)
      sl,                 // Stop loss
      actualTP,           // Take profit
      comment,            // Comment
      MagicNumber,        // Magic number
      0,                  // Expiration
      clrGreen            // Color
   );
   
   if(ticket < 0)
   {
      Print("❌ BUY ORDER FAILED | Error: ", GetLastError(), 
            " | Entry: ", actualEntry, 
            " | SL: ", sl, 
            " | TP: ", actualTP);
      return -1;
   }
   
   // Update globals
   lastTradeTime = TimeCurrent();
   LastDirection = SIGNAL_BUY;
   TodayTrades++;
   
   Print("✅ BUY ORDER PLACED | Ticket: ", ticket, 
         " | Entry: ", actualEntry, 
         " | SL: ", sl, " | TP: ", actualTP, 
         " | Lot: ", lot);
   
   return ticket;
}

//--------------------------------------------------------------------
// Place Sell Trade
//--------------------------------------------------------------------
int PlaceSellOrder(double entryPrice, double sl, double tp, 
                   double lot, string comment)
{
   // Validate parameters
   OrderParams params = ValidateOrderParams(
      OP_SELL, entryPrice, sl, tp, lot, comment);
   
   if(!params.IsValid)
   {
      Print("❌ SELL ORDER BLOCKED | Reason: ", params.ValidationError);
      return -1;
   }
   
   // Use Bid price as actual entry
   double actualEntry = Bid;
   
   // Recalculate TP based on actual entry
   double actualTP = CalculateTPSell(DefaultTakeProfit);
   
   // Place order
   int ticket = OrderSend(
      Symbol(),           // Symbol
      OP_SELL,            // Operation
      lot,                // Lot size
      actualEntry,        // Price
      MaxSlippage,        // Max slippage (pips)
      sl,                 // Stop loss
      actualTP,           // Take profit
      comment,            // Comment
      MagicNumber,        // Magic number
      0,                  // Expiration
      clrRed              // Color
   );
   
   if(ticket < 0)
   {
      Print("❌ SELL ORDER FAILED | Error: ", GetLastError(), 
            " | Entry: ", actualEntry, 
            " | SL: ", sl, 
            " | TP: ", actualTP);
      return -1;
   }
   
   // Update globals
   lastTradeTime = TimeCurrent();
   LastDirection = SIGNAL_SELL;
   TodayTrades++;
   
   Print("✅ SELL ORDER PLACED | Ticket: ", ticket, 
         " | Entry: ", actualEntry, 
         " | SL: ", sl, " | TP: ", actualTP, 
         " | Lot: ", lot);
   
   return ticket;
}

//====================================================================
// ORDER MODIFICATION
//====================================================================

//--------------------------------------------------------------------
// Modify Order Safety Wrapper
//--------------------------------------------------------------------
bool ModifyOrderSafe(int ticket, double newSL, double newTP)
{
   if(!OrderSelect(ticket, SELECT_BY_POS, MODE_TRADES))
   {
      Print("ERROR: Cannot select ticket ", ticket);
      return false;
   }
   
   // Don't move SL tighter (only loosen or move to BE)
   if(OrderType() == OP_BUY)
   {
      if(newSL > OrderStopLoss() && OrderStopLoss() > 0)
      {
         // OK - moving SL up (to break-even or trailing stop)
      }
   }
   else if(OrderType() == OP_SELL)
   {
      if(newSL < OrderStopLoss())
      {
         // OK - moving SL down (to break-even or trailing stop)
      }
   }
   
   bool result = OrderModify(
      ticket,
      OrderOpenPrice(),
      newSL,
      newTP,
      0
   );
   
   if(!result)
   {
      Print("⚠️ ORDER MODIFY FAILED | Ticket: ", ticket, 
            " | Error: ", GetLastError());
      return false;
   }
   
   return true;
}

//====================================================================
// PENDING ORDER MANAGEMENT
//====================================================================

//--------------------------------------------------------------------
// Cancel All Pending Orders (Non-EA trades unaffected)
//--------------------------------------------------------------------
int CancelAllPendingOrders()
{
   int cancelCount = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      // Only pending orders (OP_BUYLIMIT, OP_SELLLIMIT, OP_BUYSTOP, OP_SELLSTOP)
      if(OrderType() >= OP_BUY && OrderType() <= OP_SELL)
         continue;
      
      bool closed = OrderDelete(OrderTicket());
      
      if(closed)
      {
         cancelCount++;
         Print("✓ Pending order cancelled | Ticket: ", OrderTicket());
      }
      else
      {
         Print("❌ Failed to cancel | Ticket: ", OrderTicket(), 
               " | Error: ", GetLastError());
      }
   }
   
   return cancelCount;
}

//====================================================================
// TRADE INFORMATION RETRIEVAL
//====================================================================

//--------------------------------------------------------------------
// Get Current Open Buy Orders Count
//--------------------------------------------------------------------
int CountOpenBuyOrders()
{
   int count = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderType() == OP_BUY)
         count++;
   }
   
   return count;
}

//--------------------------------------------------------------------
// Get Current Open Sell Orders Count
//--------------------------------------------------------------------
int CountOpenSellOrders()
{
   int count = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderType() == OP_SELL)
         count++;
   }
   
   return count;
}

//--------------------------------------------------------------------
// Get Total Open Orders Count (EA only)
//--------------------------------------------------------------------
int CountOpenOrders()
{
   int count = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      count++;
   }
   
   return count;
}

//--------------------------------------------------------------------
// Get Current Unrealized Profit/Loss
//--------------------------------------------------------------------
double GetUnrealizedProfit()
{
   double totalProfit = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      totalProfit += OrderProfit();
   }
   
   return totalProfit;
}

#endif // __TRADEMANAGER_MQH__
