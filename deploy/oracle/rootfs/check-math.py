#!/usr/bin/python3.12
"""Small compiled-dependency checks, not Oracle answer qualification."""
import json
import numpy as np
import scipy.linalg as la
from sklearn.linear_model import LinearRegression
from sympy import factor, symbols

x = symbols('x')
a = np.array([[2., 0.], [0., 4.]])
assert np.allclose(np.linalg.solve(a, np.array([4., 8.])), [2., 2.])
assert abs(la.det(a) - 8) < 1e-10
model = LinearRegression().fit(np.array([[1.], [2.], [3.]]), np.array([3., 5., 7.]))
assert abs(model.predict(np.array([[4.]]))[0] - 9) < 1e-10
assert str(factor(x*x - 1)) == '(x - 1)*(x + 1)'
print(json.dumps({'numpy_solve': 'pass', 'scipy_linalg_det': 'pass',
                  'sklearn_linear_regression': 'pass', 'sympy_factor': 'pass',
                  'scope': 'Compiled dependency execution only; not Oracle answer qualification.'}, sort_keys=True))
