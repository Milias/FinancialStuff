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
      self.AlgoParams = struct('max_trading_volume', struct, 'lookback', 100, 'trigger_params', struct('dtsmax', 30, 'dtbmax', 30, 'dthmax', 10, 'dssmax', 0.0, 'dsbmax', 0.0));

      self.AlgoParams.max_trading_volume.DBK_EUR = 2;
      self.AlgoParams.max_trading_volume.CBK_EUR = 10;

      % Here triggers are stored as functions that only take "self" as an argument.
      % TriggersData contains information specific to each function, for bookkeeping.
      % TriggersData.Global is reserved for information concerning more than one trigger.
      self.Triggers = cell(0);
      self.TriggersData = struct;
      self.TriggersData.Global = struct;

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
      % == TrendTradeTrig ==
      % Buy stock when movmean(S, [lookback 0]) > S for dtmax ticks. 
      % TODO: how much stock? For now just the first entry.
      self.Triggers{1} = 'TrendTradeTrig';
      self.TriggersData.TrendTradeTrig = struct('tick_count_buy', 0, 'tick_count_sell', 0);

      % == ReducePositionTrig ==
      % A large position in the market (either positive or negative) should reduce
      % the holding time significantly, so that small volumes can be kept around
      % for longer than V < max_trading_volume.
      % Selling after a certain amount of time is difficult to track, so instead
      % we'll sell after N ticks holding a significant position.
      % TODO: improve this ^ function.
      self.Triggers{2} = 'TradeMatchTrig';
      self.TriggersData.TradeMatchTrig = struct('tick_count', 0);
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.AssetMgr.UpdateDepths(aDepth);
 
      % Run trigger functions.
      self.HandleTriggers();
    end

    function HandleTriggers(self)
      for trig = self.Triggers
        self.(trig{1})();
      end
    end

    % Buy when movmean(S_ask, [lookback 0]) < S_bid for dtbmax ticks.
    function TrendTradeTrig(self)
      for isin = self.AssetMgr.ISINs
        isin = isin{1};

        % Get data from the last `lookback` depths.
        myData = self.AssetMgr.GetDataFromHistory(isin, {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume'}, self.AlgoParams.lookback);

        % Compute the mean weighted with volumes of the ask prices
        % myAskMean = mean(cellfun(@(p, v) self.GetVolumePrice(p, v, self.AlgoParams.max_trading_volume.(isin)), myData.askLimitPrice, myData.askVolume));
        % myBidMean = mean(cellfun(@(p, v) self.GetVolumePrice(p, v, self.AlgoParams.max_trading_volume.(isin)), myData.bidLimitPrice, myData.bidVolume));

        % myAskMean = sum(cellfun(@(p, v) sum(p .* v), myData.askLimitPrice, myData.askVolume)) / sum(cell2mat(myData.askVolume'));
        % myBidMean = sum(cellfun(@(p, v) sum(p .* v), myData.bidLimitPrice, myData.bidVolume)) / sum(cell2mat(myData.bidVolume'));

        myAskMean = mean(cellfun(@(p) p(1), myData.askLimitPrice(logical(cellfun(@length, myData.askLimitPrice)))));
        myBidMean = mean(cellfun(@(p) p(1), myData.bidLimitPrice(logical(cellfun(@length, myData.bidLimitPrice)))));

        if length(myData.askLimitPrice{1}) && length(myData.bidLimitPrice{1})
          fprintf('am: %2.2f, cb: %2.2f\n', myAskMean, myData.bidLimitPrice{1}(1));
          fprintf('bm: %2.2f, ca: %2.2f\n\n', myBidMean, myData.askLimitPrice{1}(1));
          if myAskMean < myData.bidLimitPrice{1}(1)
            self.TriggersData.TrendTradeTrig.tick_count_buy = self.TriggersData.TrendTradeTrig.tick_count_buy + 1;
          end

          if myBidMean > myData.askLimitPrice{1}(1)
            self.TriggersData.TrendTradeTrig.tick_count_sell = self.TriggersData.TrendTradeTrig.tick_count_sell + 1;
          end

          if self.TriggersData.TrendTradeTrig.tick_count_buy == self.AlgoParams.trigger_params.dtbmax
            self.TriggersData.TrendTradeTrig.tick_count_buy = 0;
            myPos = self.AssetMgr.GetISINPosition(isin);
            myVol = min(max(0, self.AlgoParams.max_trading_volume.(isin) - abs(myPos)), myData.askVolume{1}(1));
            if myVol > 0
              fprintf('\nTrendTradeTrig - Buy\n');
              if self.Trade(isin, myData.askLimitPrice{1}(1), myVol) > 0
                self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end), self.ownTrades.side(end)*self.ownTrades.volume(end));
              end
            end
          end
 
          if self.TriggersData.TrendTradeTrig.tick_count_sell == self.AlgoParams.trigger_params.dtsmax
            self.TriggersData.TrendTradeTrig.tick_count_sell = 0;
            myPosition = self.AssetMgr.GetISINPosition(isin);
            myVol = min(max(0, self.AlgoParams.max_trading_volume.(isin) - abs(myPos)), myData.bidVolume{1}(1));
            
            if myVol > 0
              fprintf('\nTrendTradeTrig - Sell\n');
              if self.Trade(isin, myData.bidLimitPrice{1}(1), -myVol) > 0
                self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end), self.ownTrades.side(end)*self.ownTrades.volume(end));
              end
            end
          end
        end
      end
    end

    function TradeMatchTrig(self)
      for isin = self.AssetMgr.ISINs
        isin = isin{1};

        for i = 1:length(self.AssetMgr.ActiveTrades.(isin))
          trade = self.AssetMgr.ActiveTrades.(isin){i};

          myPos = sum(trade.volume);
          if myPos < 0
            myLabels = {'askLimitPrice', 'askVolume'};
          else
            myLabels = {'bidLimitPrice', 'bidVolume'};
          end

          myData = self.AssetMgr.GetDataFromHistory(isin, myLabels, 0);

          if length(myData.(myLabels{1}){1})
            if myData.(myLabels{1}){1}(1) > trade.price(1)
              fprintf('Before -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', i, myPos, -sign(myPos)*sum(trade.price .* trade.volume));

              myTrades = self.Trade(isin, myData.(myLabels{1}){1}(1), -min(myPos, myData.(myLabels{2}){1}(1)));

              self.AssetMgr.ActiveTrades.(isin){i}.price = [ self.AssetMgr.ActiveTrades.(isin){i}.price ; self.ownTrades.price(end-myTrades+1:end) ];

              self.AssetMgr.ActiveTrades.(isin){i}.volume = [ self.AssetMgr.ActiveTrades.(isin){i}.volume ; self.ownTrades.side(end-myTrades+1:end).*self.ownTrades.volume(end-myTrades+1:end) ];

              fprintf('After -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', i, sum(self.AssetMgr.ActiveTrades.(isin){i}.volume), - sign(myPos) * sum(self.AssetMgr.ActiveTrades.(isin){i}.price .* self.AssetMgr.ActiveTrades.(isin){i}.volume));
            end
          end
        end
      end

      % fprintf('Before. Active: %d, Completed: %d\n', sum(cellfun(@(isin) length(self.AssetMgr.ActiveTrades.(isin)), self.AssetMgr.ISINs)), sum(cellfun(@(isin) length(self.AssetMgr.CompletedTrades.(isin)), self.AssetMgr.ISINs)))
      self.AssetMgr.ArchiveCompletedTrades();
      % fprintf('After. Active: %d, Completed: %d\n', sum(cellfun(@(isin) length(self.AssetMgr.ActiveTrades.(isin)), self.AssetMgr.ISINs)), sum(cellfun(@(isin) length(self.AssetMgr.CompletedTrades.(isin)), self.AssetMgr.ISINs)))
    end 

    function thePrice = GetVolumePrice(self, aP, aV, aLimitVol)
      % Computes the average price of purchasing a volume `aLimitVol`.
      myVcs = cumsum(aV);
      myIndex = myVcs < aLimitVol;
      myNextIndex = find(~myIndex, 1);
      thePrice = (sum(aP(myIndex) .* aV(myIndex)) + aP(myNextIndex) * (aLimitVol - myVcs(myNextIndex)) / aLimitVol);
    end

    function theConfirmation = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      % Returns whether the order was successful or not.
      myCurrentTrades = length(self.ownTrades.price);
      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);
      myTradeCount = length(self.ownTrades.price) - myCurrentTrades;
      theConfirmation = myTradeCount;
 
      myLabels = {'askVolume', 'bidVolume'};

      myData = self.AssetMgr.ComputeDataFromHistory(aISIN, myLabels, 0, { @sum, @sum });

      fprintf('Trade info: %7s, %5.2f, %3.0f. MaxVol: %3.0f/%3.0f\n', aISIN, aP, aV, myData.(myLabels{1}){end}, myData.(myLabels{2}){end});
      % Here we iterate over all the trades done (in case aV > first entry's volume),
      % updating our assets and book.
      for i = 1:myTradeCount
        fprintf('Trade: %5.2f, %3.0f - ', self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        if theConfirmation
          fprintf('Correct.\n');
          self.AssetMgr.UpdateAssets(aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
          fprintf('Profit (%7s): %5.2f, total: %5.2f\n', aISIN, self.AssetMgr.GetISINProfit(aISIN), self.AssetMgr.GetTotalProfit());
        end
      end
      fprintf('\n')
    end

    function TradeFullStock(self, aISIN, aV)
      % Try to buy/sell the volume aV.
      if aV > 0
        myLabels = {'askLimitPrice', 'askVolume'};
      else
        myLabels = {'bidLimitPrice', 'bidVolume'};
      end

      myData = self.AssetMgr.GetDataFromHistory(aISIN, myLabels, 0);
      if length(myData.(myLabels{1}){end}) > 0 && length(myData.(myLabels{2}){end}) > 0
        self.Trade(aISIN, myData.(myLabels{1}){end}(end), aV);
      end
    end

    function Unwind(self)
      % Sell sell sell!!
      for isin = self.AssetMgr.ISINs
        isin = isin{1};
        myPos = self.AssetMgr.GetISINPosition(isin);
        self.TradeFullStock(isin, -myPos)
      end

      self.AssetMgr.delete();
    end
  end
end
