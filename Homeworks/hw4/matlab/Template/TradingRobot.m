classdef TradingRobot < AutoTrader
  properties
    AssetMgr
    AlgoParams
    Triggers
    TriggersData
    PerfMeasure
  end

  methods
    function self = TradingRobot
      % Initializing the assets manager with the two ISINs.
      self.AssetMgr = AssetManager;
      self.AssetMgr.Init({'DBK_EUR', 'CBK_EUR'});

      % This struct contains basic parameters of the algorithm.
      % max_trading_volume :    maximum amount of shares to hold at any given tick.
      % lookback :              number of past ticks to consider for computations.
      % trigger_params :        several parameters used mainly for triggers.1
      %   dtsmax :              number of ticks we wait before selling stock.
      %   dtbmax :              number of ticks we wait before buying stock.
      %   dthmax :              maximum ticks we hold to the stock.
      %   dssmax :              maximum change of the stock's price before selling.
      %   dsbmax :              change in price before buying.
      self.AlgoParams = struct('max_trading_volume', 100, 'lookback', 10, 'trigger_params', struct('dtsmax', 0, 'dtbmax', 2, 'dthmax', 10, 'dssmax', 0.0, 'dsbmax', 0.0));

      % Here triggers are stored as functions that only take "self" as an argument.
      % TriggersData contains information specific to each function, for bookkeeping.
      self.Triggers = cell(0);
      self.TriggersData = struct;

      % Placeholder struct to store performance-related stuff.
      self.PerfMeasure = struct;

      % Initialize triggers.
      self.InitTriggers();
    end
    
    function delete(self)
      % Destructor.
      clear self.AssetMgr;
      clear self.AlgoParams;
      clear self.Triggers;
      clear self.TriggersData;
      clear self.PerfMeasure;
    end

    function InitTriggers(self)
      % == BasicBuyTrig ==
      % Buy stock when movmean(S, [lookback 0]) > S for dtmax ticks. 
      % TODO: how much stock? For now just the first entry.
      self.Triggers{1} = @BasicBuyTrig;
      self.TriggersData.BasicBuyTrig = struct('tick_count', 0);

      % == BasicSellTrig ==
      % A large position in the market (either positive or negative) should reduce
      % the holding time significantly, so that small volumes can be kept around
      % for longer than V > max_trading_volume.
      % Selling after a certain amount of time is difficult to track, so instead
      % we'll sell after N ticks holding a significant position.
      % TODO: improve this ^ function.
      self.Triggers{2} = @BasicSellTrig;
      self.TriggersData.BasicSellTrig = struct('tick_count', 0);
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.AssetMgr.UpdateDepths(aDepth);

      % Run trigger functions.
      self.HandleTriggers();
    end

    function HandleTriggers(self)
      for i = 1:length(self.Triggers)
        self.Triggers{i}(self);
      end
    end

    % Buy when movmean(S_ask, [lookback 0]) < S_bid for dtbmax ticks.
    function BasicBuyTrig(self)
      for i = 1:length(self.AssetMgr.ISINs)
        myISIN = self.AssetMgr.ISINs{i};

        % Get data from the last `lookback` depths.
        myData = self.AssetMgr.GetDataFromHistory(myISIN, {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume'}, self.AlgoParams.lookback);

        % Compute the mean weighted with volumes of the ask prices.
        myAskMean = sum(cellfun(@(p, v) sum(p .* v), myData.askLimitPrice, myData.askVolume)) / sum(cell2mat(myData.askVolume'));

        if length(myData.askLimitPrice{end}) && length(myData.bidLimitPrice{end})
          % fprintf('a: %2.2f, b: %2.2f\n', myAskMean, myData.bidLimitPrice{end}(1));
          if myAskMean < myData.bidLimitPrice{end}(1)
            self.TriggersData.BasicBuyTrig.tick_count = self.TriggersData.BasicBuyTrig.tick_count + 1;
          end

          if self.TriggersData.BasicBuyTrig.tick_count == self.AlgoParams.trigger_params.dtbmax
            self.TriggersData.BasicBuyTrig.tick_count = 0;
            myVol = self.AlgoParams.max_trading_volume - self.AssetMgr.GetISINVolume(myISIN, 1)
            if myVol > 0
              fprintf('BasicBuyTrig\n');
              self.Trade(myISIN, myData.askLimitPrice{end}(1), myData.askVolume{end}(1));
            end
          end
        end
      end
    end

    % Basic selling trigger: sell after dthmax ticks or if the price decreases
    % for more than dtsmax ticks.
    function BasicSellTrig(self)
      % Count for how many ticks our position has been higher than max_trading_volume.
      if abs(self.AssetMgr.GetTotalVolume()) > self.AlgoParams.max_trading_volume
        self.TriggersData.BasicSellTrig.tick_count = self.TriggersData.BasicSellTrig.tick_count + 1;
      end
            
      if self.TriggersData.BasicSellTrig.tick_count == self.AlgoParams.trigger_params.dthmax
        % Get positive position and try to sell that.
        cellfun(@(isin) self.TradeFullStock(isin, -self.AssetMgr.GetISINVolume(isin, 1)), self.AssetMgr.ISINs)

        % Same with negative position. 
        cellfun(@(isin) self.TradeFullStock(isin, -self.AssetMgr.GetISINVolume(isin, -1)), self.AssetMgr.ISINs)
      end
    end 

    function thePrice = ComputeTradingPrice(self, aP, aV)
      aVcs = cumsum(aV);
      myIndex = aVcs < self.AlgoParams.max_trading_volume;
      myNextIndex = find(~myIndex, 1);
      thePrice = (sum(aP(myIndex) .* aV(myIndex)) + aP(myNextIndex)*(aVcs(myNextIndex) - aV)) / (sum(aV(myIndex)) + aVcs(myNextIndex) - aV);
    end

    function [theConfirmation] = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      % Returns whether the order was successful or not.
      myCurrentTrades = length(self.ownTrades.price);
      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);
      myTradeCount = length(self.ownTrades.price) - myCurrentTrades;
      theConfirmation = myTradeCount > 0;
       
      fprintf('Trade info: %7s, %3.2f, %3.0f\n', aISIN, aP, aV);
      % Here we iterate over all the trades done (in case aV > first entry's volume),
      % updating our assets and book.
      for i = 1:myTradeCount
        fprintf('Trade: %3.2f, %3.0f - ', self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        if theConfirmation
          fprintf('Correct.\n');
          self.AssetMgr.UpdateAssets(aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        else
          fprintf('Rejected.\n');
        end
      end
    end

    function TradeFullStock(self, aISIN, aV)
      % Try to buy/sell the volume aV.
      if aV > 0
        myLabels = {'askLimitPrice', 'askVolume'};
      else
        myLabels = {'bidLimitPrice', 'bidVolume'};
      end


      myData = self.AssetMgr.GetDataFromHistory(aISIN, myLabels, 0);
      %{
      % This is not working, for now we'll trade only with the first entry.

      if size(myData.(myLabels{1}){end}, 2) > 0 && size(myData.(myLabels{2}){end}, 2) > 0
        disp('aV - cumsum')
        disp(abs(aV) - [ 0 ; cumsum(myData.(myLabels{2}){end}(1:end-1))])
        disp('volume')
        disp(myData.(myLabels{2}){end})
        myVol = min(abs(aV) - [ 0 ; cumsum(myData.(myLabels{2}){end}(1:end-1))], myData.(myLabels{2}){end})
        myIndex = myVol > 0;
        arrayfun(@(p, v) self.Trade(aISIN, p, sign(aV)*v), myData.(myLabels{1}){end}(myIndex), -myVol(myIndex));
      end
      %}

      if length(myData.(myLabels{1}){end}) > 0 && length(myData.(myLabels{2}){end}) > 0
        fprintf('TradeFullStock - \n');
        self.Trade(aISIN, myData.(myLabels{1}){end}(1), sign(aV) * min(myData.(myLabels{2}){end}(1), abs(aV)));
      end
    end

    function Unwind(self)
      % Sell sell sell!!
      for myISIN = self.AssetMgr.ISINs
        myISIN = myISIN{1};
        for myTrade = self.AssetMgr.Assets.(myISIN)
          myTrade = myTrade{1};
          % self.Trade(myISIN, myTrade.price, -myTrade.volume);
        end
      end

      self.AssetMgr.delete();
    end
  end
end
