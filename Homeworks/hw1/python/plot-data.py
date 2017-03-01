#!/bin/python
# -*- coding:utf8 -*-
from numpy import *
import matplotlib.pyplot as plt

def p_oP_plot():
  X = loadtxt('../data/P.txt', delimiter=',')
  Y = loadtxt('../data/oP.txt', delimiter=',')

  plt.plot(X, Y, 'r-')
  plt.axis([0.0, 1.0, 0.0, amax(Y)])

  plt.title('Expected profit - risky approach')
  plt.xlabel('P / Risk')
  plt.ylabel(r'$\langle oP \rangle_r$ / Expected profit')

  plt.savefig('../tex/graphs/P-oP.eps')
  plt.clf()

def p_profit_plot():
  X = loadtxt('../data/P.txt', delimiter=',')
  Y = loadtxt('../data/profit.txt', delimiter=',')

  plt.plot(X, Y, 'r-')
  plt.axis([0.0, 1.0, 1.0, amax(Y)])

  plt.title('Expected profit% - risky approach')
  plt.xlabel('P / Risk')
  plt.ylabel(r'1 + $\frac{\langle oP \rangle_r}{aE}$ / Expected profit%')

  plt.savefig('../tex/graphs/P-Profit.eps')
  plt.clf()

p_oP_plot()
p_profit_plot()
