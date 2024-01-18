# Presolve algorithm 

>### Ruslan Sadykov, 20/10/2023, revised 16/01/2024

The document presents the presolve algorithm implemented in _Coluna_. Is it particularly important to run the this algorithm after augmenting the partial solution in rounding and diving heuristics. 

## 1. Augmenting the partial solution

This is an optional step, which should be performed in the case a local partial solution is passed in the input of the preprocessing algorithm.

Consider a _local partial solution_ $(\bar{\bm x}^{\rm pure}, \bar{\bm\lambda})$ (where $\bar{\bm x}^{\rm pure}$ is the vector of values for pure master variables, and $\bar{\bm\lambda}$ is the vector of values for master columns), which should be added to the _global partial solution_ $(\hat{\bm x}^{\rm pure}, \hat{\bm\lambda})$. 

First, we augment the global partial solution: $(\hat{\bm x}^{\rm pure}, \hat{\bm\lambda})\leftarrow(\hat{\bm x}^{\rm pure}+\bar{\bm x}^{\rm pure}, \hat{\bm\lambda}+\bar{\bm\lambda})$. 

Second, we update the right-hand side values of all master constraints (both robust and non-robust): ${\rm rhs}_i\leftarrow {\rm rhs}_i - {\bm A}^{\rm pure}\cdot\bar{\bm x}^{\rm pure} - {\bm A}^{\rm col}\cdot\bar{\bm \lambda}$, where ${\bm A}^{\rm pure}$ is the matrix of coefficients of pure master constraints and ${\bm A}^{\rm col}$ is the matrix of coefficients of master columns. 

Third, we update subproblem multiplicities $U_k\leftarrow U_k - \sum_{q\in Q_k}\bar\lambda_q$, and $L_k\leftarrow \max\left\{0,\; L_k - \sum_{q\in Q_k}\bar\lambda_q\right\}$, where $Q_k$ is the set of indices of columns associated with solutions from subproblem $k$.

Afterwards, we should update the bounds of pure master variables and representative master variables. For that we first calculate the representative local partial solution: $\bar{\bm x}^{\rm repr} = \sum_{q\in Q}{\bm s}^q\cdot \bar\lambda_q$, where $Q$ is the total number of columns, and ${\bm s}^q$ is the subproblem solution associated with column $\lambda_q$. Update of bounds of variables can be performed one variable at a time. This is presented in the next two sections. 

### Pure master variables 

Consider a pure master variable $x^{\rm pure}_j$ with $\bar{x}^{\rm pure}_j\neq 0$ and bounds $[lb_j,ub_j]$ before augmenting the partial solution. 

If $\bar{x}^{\rm pure}_j > 0$, then we have $lb_j\leftarrow \max\left\{0, lb_j - \bar{x}^{\rm pure}_j\right\}$, $ub_j\leftarrow ub_j - \bar{x}^{\rm pure}_j$.

If $\bar{x}^{\rm pure}_j < 0$, then we have $lb_j\leftarrow lb_j - \bar{x}^{\rm pure}_j$, $ub_j\leftarrow \min\left\{0, ub_j - \bar{x}^{\rm pure}_j\right\}$.

> _**Note:**_ An alternative would be to fix pure master variable $x^{\rm pure}_j$ by setting $lb_j\leftarrow 0$ and $ub_j\leftarrow 0$. This would leave less freedom for future updates of the partial solution (i.e. this would lead to a more aggressive diving for example). 

### Representative variables 

We consider a representative master variable $x^{\rm repr}_j$ with bounds $[lb^g_j, ub^g_j]$ before augmenting the partial solution. We assume that $x^{\rm repr}_j$ represents exactly one variable $x^k_j$ in subproblem $k$ with bounds $[lb^l_j, ub^l_j]$ before augmenting the partial solution. _This assumption should be verified before augmenting the partial solution!_  For the clarity of presentation, we omit index $j$ for the remainder of this 
section.

After augmenting the partial solution, the following inequalities should be satisfied:
$$ lb^g - \bar{x}^{\rm repr}\leq x^{\rm repr} \leq ub^g - \bar{x}^{\rm repr}.$$

At the same time, we should have 
$$\min\{lb^l\cdot L_k,\; lb^l\cdot U_k\}\leq x^{\rm repr}\leq \max\{ub^l\cdot U_k,\; ub^l\cdot L_k\}$$

Thus, the following update should be done 
$$ lb^g\leftarrow \max\left\{lb^g - \bar{x}^{\rm repr},\; \min\{lb^l\cdot L_k,\; lb^l\cdot U_k\}\right\}$$
$$ ub^g\leftarrow  \min\left\{ub^g - \bar{x}^{\rm repr},\; \max\{ub^l\cdot U_k,\; ub^l\cdot L_k\}\right\}$$

> _**Example 1:**_ Let $0\leq x^k\leq 3$, $0\leq x^{\rm repr}\leq 6$, $L_k=0$, and $U_k=2$ before augmenting the partial solution. Let local partial solution $\bar{x}^{\rm repr}=2$. After augmenting partial solution, we have $U_k\leftarrow 1$ and
> $$ \max\left\{-2,\; 0\right\}\leq x^{\rm repr} \leq \min\left\{4,\; 3\right\} \Rightarrow 0 \leq x^{\rm repr} \leq 3$$

> _**Example 2:**_ Let $0\leq x^k\leq 5$, $3\leq x^{\rm repr}\leq 6$, $L_k=0$, and $U_k=2$ before augmenting the partial solution. Let local partial solution  $\bar{x}^{\rm repr}=2$. Then after augmenting the partial solution, we have $U_k\leftarrow 1$ and
> $$ \max\left\{1,\; 0\right\}\leq x'_{\rm repr} \leq \min\left\{4,\; 5\right\} \Rightarrow 1 \leq x'_{\rm repr} \leq 4$$

> _**Example 3:**_ $-1\leq x^k\leq 4$, $-2\leq x^{\rm repr}\leq 2$, $L_k=0$, $U_k=2$. Let $\bar{x}^{\rm repr}=-1$. Then after augmenting the partial solution, we have 
> $$ \max\left\{-1,\; -1\right\}\leq x^{\rm repr} \leq \min\left\{3,\; 4\right\} \Rightarrow -1 \leq x^{\rm repr} \leq 3$$

### Implementation details

To update bounds of representative and pure master variables in an unified way after augmenting a partial solution, we first calculate so-called _variable domains_. For a subproblem variable $x_j^k$, its domain  is obtained as follows:
$$[{\rm dom}^-_j,\;{\rm dom}^+_j] = \left[\min\{lb^l_j\cdot L_k,\; lb^l_j\cdot U_k\}, \max\{ub^l_j\cdot U_k,\; ub^l_j\cdot L_k\}\right]$$

For a pure master variable $x^{\rm pure}_j$, its domain depends on value $\bar{x}^{\rm pure}_j$:
$$ [{\rm dom}^-_j,\;{\rm dom}^+_j] = \left\{ \begin{array}{ll} [0,+\infty), & \text{ if } \bar{x}^{\rm pure}_j > 0, \\ (-\infty,0], & \text{ if } \bar{x}^{\rm pure}_j < 0, \\ (-\infty,+\infty), & \text{ if } \bar{x}^{\rm pure}_j = 0. \\ \end{array}\right.$$
 
After calculating variable domains, their bounds can be updated simply by 
$$ lb_j\leftarrow \max\left\{lb_j - \bar{x}_j,\; {\rm dom}_j^-\right\}$$
$$ ub_j\leftarrow  \min\left\{ub_j - \bar{x}_j,\; {\rm dom}_j^+\right\}$$

## 2. Preprocessing "core"

This step is always performed. Preprocessing is done iteratively for a fixed number of iterations. Each iteration consists of the following steps.

### Presolving the representative master

Here we apply the standard MIP presolving of the representative master formulation consisting of pure master constraints, representative master variables, and robust master constraints. _Non-robust constraints should be excluded from presolving!_ Such presolve updates slacks of constraints and bounds of variables. It may
* deactivate redundant constraints, 
* fix pure master variables $x_j^{\rm pure}$ with bounds $lb_j=ub_j$ (in this case $\bar{x}_j^{\rm pure}=lb_j$ is added to the global partial solution, we set $lb_j=ub_j\leftarrow 0$ and update the corresponding right-hand-sides of constraints).
* detect infeasibility due to variables $x_j^{\rm pure}$ or $x_j^{\rm repr}$ such that $lb_j>ub_j$ (in this case the whole procedure stops with infeasibility).
* deactivate pure master variables $x_j^{\rm pure}$ with bounds $lb_j=ub_j=0$.
  
### Propagate bounds from representative master variables to subproblem variables 

For each subproblem $k$, $U_k\geq 1$, and each subproblem variable $x_j^k$, we set: 
$$lb^l_j\leftarrow \max\left\{lb^l_j,\; lb^g_j - (U_k-1)\cdot ub^l_j\right\}$$
$$ub^l_j\leftarrow \min\left\{ub^l_j,\; ub^g_j - \max\{0, L_k-1\}\cdot lb^l_j\right\}$$

### Presolving the subproblems

Again, the standard MIP presolving is applied for each subproblem $k$. Such presolve updates slacks of constraints and bounds of variables. It may
* remove redundant constraints, 
* detect infeasibility due to variables $x_j^k$ such that $lb^l_j>ub^l_j$ (in this case we set $L_k=U_k\leftarrow 0$).
* deactivate variables $x_j^k$ with bounds $lb_j^l=ub_j^l=0$ (in this case representative variables $x_j^{\rm repr}$ in the master are also deactivated).

### Updating subproblem multiplicities

For each subproblem $k$, $U_k\geq 1$, we try to update its multiplicities, based on local and global bounds of its variables. Consider a variable $x_j^k$,
* If $lb^g_j>0$ and $ub^l>0$, then $L_k\leftarrow\max\{L_k, \lceil lb^g_j/ub^l_j\rceil\}$

* If $ub^g_j<0$ and $lb^l<0$, then $L_k\leftarrow\max\{L_k, \lceil ub^g_j/lb^l_j\rceil\}$

* If $lb^l_j>0$ and $ub^g>0$, then $U_k\leftarrow\min\{U_k, \lfloor ub^g_j/lb^l_j\rfloor\}$

* If $ub^l_j<0$ and $lb^g<0$, then $U_k\leftarrow\min\{U_k, \lfloor lb^g_j/ub^l_j\rfloor\}$

### Propagate bounds from subproblem variables to representative master variables

For each representative variable $x^{\rm repr}_j$ representing variable $x_j^k$ in subproblem $k$: 
$$lb^g_j\leftarrow \max\left\{lb^g_j,\; \min\{lb^l_j\cdot L_k,\; lb^l_j\cdot U_k\}\right\}$$
$$ub^g_j\leftarrow \min\left\{ub^g_j,\; \max\{ub^l_j\cdot L_k,\; ub^l_j\cdot U_k\}\right\}$$

## 3. Removing non-proper columns

Finally, we should deactivate non-proper columns for each subproblem $k$, i.e., columns $\lambda_q$, $q\in Q_k$, such that $s^q_j<lb^l_j$ or $s^q_j>ub^l_j$, where $s^q_j$ is the value of variable $x_j^k$ in solution ${\bm s}_q$ associated with column $\lambda_q$.
