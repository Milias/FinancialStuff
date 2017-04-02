classdef TradingRobot < AutoTrader
  properties
    AssetMgr = AssetManager;

    % This struct contains basic parameters of the algorithm.
    % max_trading_volume :    maximum amount of shares to hold at any given tick.
    % lookback :              number of past ticks to consider for computations.
    % trigger_params :        several parameters used mainly for triggers.1
    %   dtsmax :              maximum number of ticks some volume is kept before being sold.
    %   dtbmax :              number of ticks we wait before buying stock.
    %   dssmax :              maximum change of the stock's price before selling.
    %   dsbmax :              change in price before buying.
    AlgoParams = struct('max_trading_volume', 0, 'lookback', 0, 'trigger_params', struct('dtsmax', 0, 'dtbmax', 0, 'dssmax', 0.0, 'dsbmax', 0.0));

    % Here triggers are stored as functions that only take "self" as an argument.
    % TriggersData contains information specific to each function, for bookkeeping.
    Triggers = {};
    TriggerData = {};

    % Placeholder struct to store performance-related stuff.
    PerfMeasure = struct;
  end

  methods
    function self = TradingRobot
      % Initializing the assets manager with the two ISINs.
      self.AssetMgr.Init({'DBK_EUR', 'CBK_EUR'});
    end

    function InitTriggers(self)
      % BasicBuyTrig : buy stock when movmean(S, [lookback 0]) > S for dtmax ticks. 
      % TODO: how much stock?
      self.Triggers{1} = @BasicBuyTrig;
      self.TriggersData{1} = struct('tick_count', 0);
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.AssetMgr.UpdateDepths(aDepth);
    end

    function HandleTriggers(self)
      for i = size(self.Triggers, 2)
        self.Triggers{i}(self);
      end
    end

    % Buy when movmean(S, [lookback 0]) > S for dtmax ticks.
    function BasicBuyTrig(self)
      for aISIN = self.AssetMgr.ISINs
        myMM = mean(cellfun(@(depth) , self.AssetMgr.DepthHistory.(aISIN)
    end

    function [theConfirmation] = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      % Returns whether the order was successful or not.
      myCurrentTrades = size(self.ownTrades.price, 1);

      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);
      
      myTradeCount = size(self.ownTrades.price, 1) - myCurrentTrades;

      theConfirmation = myTradeCount > 0;
 
      if theConfirmation
        % Here we iterate over all the trades done (in case aV > first entry's volume),
        % updating our assets and book.
        for i = 1:myTradeCount
          fprintf('Trade (side: %d, %d): %7s, %3.2f, %3.0f\n', sign(aV), theConfirmation, aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));

          self.AssetMgr.UpdateAssets(aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        end
      end
    end

    function Unwind(self)
      clear self.AssetMgr;
    end
  end
end
