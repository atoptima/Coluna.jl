# Augmenting the partial solution in _Coluna_: pre-processing

>### Ruslan Sadykov, 19/10/2023

Consider a _local partial solution_ $(\bar{\bm x}^{\rm pure}, \bar{\bm\lambda})$ (where $\bar{\bm x}^{\rm pure}$ is the vector of values for pure master variables, and $\bar{\bm\lambda}$ is the vector of values for master columns), which should be added to the _global partial solution_ $(\bar{\bm y}^{\rm pure}, \bar{\bm\theta})$. 

First, we augment the global partial solution: $(\bar{\bm y}^{\rm pure}, \bar{\bm\theta})\leftarrow(\bar{\bm x}^{\rm pure}+\bar{\bm y}^{\rm pure}, \bar{\bm\lambda}+\bar{\bm\theta})$. 

Second, we update the right-hand side values of the master constraints: ${\rm rhs}_i\leftarrow {\rm rhs}_i - {\bm A}^{\rm pure}\cdot\bar{\bm x}^{\rm pure} - {\bm A}^{\rm col}\cdot\bar{\bm \lambda}$, where ${\bm A}^{\rm pure}$ is the matrix of coefficients of pure master constraints and ${\bm A}^{\rm col}$ is the matrix of coefficients of master columns. 

Third, we update subproblem multiplicities $U_k\leftarrow U_k - \sum_{q\in Q_k}\bar\lambda_q$, and $L_k\leftarrow \max\left\{0,\; L_k - \sum_{q\in Q_k}\bar\lambda_q\right\}$, where $Q_k$ is the set of indices of columns associated with solutions from subproblem $k$.

Afterwards, we should update the bounds of pure master variables and representative master variables. For that we first calculate the representative local partial solution: $\bar{\bm x}^{\rm repr} = \sum_{q\in Q}{\bm s_q}\cdot \bar\lambda_q$, where $Q$ is the total number of columns, and ${\bm s_q}$ is the subproblem solution associated with column $\lambda_q$. Update of bounds of variables can be performed one variable at a time. This is presented in the next two sections. 

## Pure master variables 

Consider a pure master variable $x^{\rm pure}_j$ with $\bar{x}^{\rm pure}_j\neq 0$ and bounds $[lb_j,ub_j]$ before augmenting the partial solution. 

If $\bar{x}^{\rm pure}_j > 0$, then we have $lb_j\leftarrow 0$, $ub_j\leftarrow ub_j - \bar{x}^{\rm pure}_j$.

If $\bar{x}^{\rm pure}_j < 0$, then we have $lb_j\leftarrow lb_j - \bar{x}^{\rm pure}_j$, $ub_j\leftarrow 0$.


## Representative variables 

We consider a representative master variable $x^{\rm repr}_j$ with bounds $[lb^g_j, ub^g_j]$ before augmenting the partial solution. We assume that $x^{\rm repr}_j$ represents exactly one variable $x^k_j$ in subproblem $k$ with bounds $[lb^l_j, ub^l_j]$ before augmenting the partial solution. _This assumption should be verified before augmenting the partial solution!_  For the clarity of presentation, we omit index $j$ for the remainder of this 
section.

After augmenting the partial solution, the following inequalities should be satisfied:
$$ lb^g - \bar{x}^{\rm repr}\leq x^{\rm repr} \leq ub^g - \bar{x}^{\rm repr}.$$

At the same time, we should have 
$$\min\{lb^l\cdot L_k,\; lb^l\cdot U_k\}\leq x^{\rm repr}\leq \max\{ub^l\cdot U_k,\; ub^l\cdot L_k\}$$

Thus, the following update should be done 
$$ lb^g\leftarrow \max\left\{lb^g - \bar{x}^{\rm repr},\; \min\{lb^l\cdot L_k,\; lb^l\cdot U_k\}\right\}$$
$$ ub^g\leftarrow  \min\left\{ub^g - \bar{x}^{\rm repr},\; \max\{ub^l\cdot U_k,\; ub^l\cdot L_k\}\right\}$$

> _**Example 1:**_ $0\leq x^k\leq 3$, $0\leq x^{\rm repr}\leq 6$, $L_k=0$, $U_k=2$. Let $\bar{x}^{\rm repr}=2$. Then after augmenting the partial solution, we have 
> $$ \max\left\{-2,\; 0\right\}\leq x^{\rm repr} \leq \min\left\{4,\; 3\right\} \Rightarrow 0 \leq x^{\rm repr} \leq 3$$

> _**Example 2:**_ $0\leq x^k\leq 5$, $3\leq x^{\rm repr}\leq 6$, $L_k=0$, $U_k=2$. Let $\bar{x}^{\rm repr}=2$. Then after augmenting the partial solution, we have 
> $$ \max\left\{1,\; 0\right\}\leq x'_{\rm repr} \leq \min\left\{4,\; 5\right\} \Rightarrow 1 \leq x'_{\rm repr} \leq 4$$

> _**Example 3:**_ $-1\leq x^k\leq 4$, $-2\leq x^{\rm repr}\leq 2$, $L_k=0$, $U_k=2$. Let $\bar{x}^{\rm repr}=-1$. Then after augmenting the partial solution, we have 
> $$ \max\left\{-1,\; -1\right\}\leq x^{\rm repr} \leq \min\left\{3,\; 4\right\} \Rightarrow -1 \leq x^{\rm repr} \leq 3$$