# -*- coding:utf8 -*-
import sys
from numpy import *
from scipy.stats import *
import matplotlib.pyplot as plt

vals = random.normal(1.0, 1.0, size = (100000,))
vals = maximum(vals, 0)
[hist, edges] = histogram(vals, 50)

width = (edges[1] - edges[0])
center = (edges[1:] + edges[:-1]) / 2.0

plt.bar(center, hist, align = 'center', width = width)
plt.plot([0, 0], [0, 1.1*max(hist)], 'g--')

plt.axis([0, 5, 0, 6000])

plt.title('Example histogram of adjusted Normal distribution')
plt.xlabel('Share value minus exercise price')
plt.ylabel('Counts')

plt.savefig('../tex/graphs/ex-normal-2.eps')
plt.show()
