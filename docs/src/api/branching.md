```@meta
CurrentModule = Coluna
```

# Branching API

Coluna provides default implementations for the branching algorithm and the strong branching algorithms.
Both implementations are built on top of an API that we describe here.

## Candidates selection

Candidates selection is the first step (and sometimes the only step) of any branching algorithm.
It chooses what are the possible branching constraints that will generate
the children of the current node of the branch-and-bound tree.

Coluna provides the following function for this step:

```@docs
Branching.select!
```

It works as follows.

The user chooses one or several branching rules that indicate the type of branching he wants
to perform.
This may be on a single variable or on a linear expression of variables for instance. 

The branching rule must implement `apply_branching_rule` that generates the candidates. 
The latter are the variables or expressions on which the branch-and-bound may branch with
additional information that is requested by Coluna's branching implementation through the
API.

Then, candidates are sorted according to a selection criterion (e.g. most fractional).
The algorithm keeps a certain number of candidates (one for classic branching, and several for strong branching).
It generates the children of each candidate kept.
At last, it returns the candidates kept.

### Branching rule

```@docs
Branching.AbstractBranchingRule
Branching.apply_branching_rule
```

### Candidate

```@docs
Branching.AbstractBranchingCandidate
Branching.getdescription
Branching.get_lhs
Branching.get_local_id
Branching.generate_children!
```

### Selection criterion

```@docs
Branching.AbstractSelectionCriterion
Branching.select_candidates!
```

### Branching API

```@docs
Branching.get_selection_nb_candidates
Branching.branching_context_type
Branching.new_context
Branching.get_int_tol
Branching.get_rules
Branching.get_selection_criterion
```

Method `advanced_select!` is part of the API but presented just below.

## Advanced candidates selection

If the candidates' selection returns several candidates will all their children, advanced candidates selection must keep only one of them.

The advanced candidates' selection is the place to evaluate the children to get relevant
additional key performance indicators about each branching candidate.

Coluna provides the following function for this step.

```@docs
Branching.advanced_select!
```

Coluna has two default implementations for this method:
- for the classic branching that does nothing because the candidates selection returns 1 candidate
- for the strong branching that performs several evaluations of the candidates.

Let us focus on the strong branching. 
Strong branching is a procedure that heuristically selects a branching constraint that
potentially gives the best progress of the dual bound.
The procedure selects a collection of branching candidates based on their branching rule
(done in classic candidate selection) 
and their score (done in advanced candidate selection).
Then, the procedure evaluates the progress of the dual bound in both branches of each branching
candidate by solving both potential children using a conquer algorithm.
The candidate that has the largest score is chosen to be the branching constraint.

However, the score can be difficult to compute. For instance, when the score is based on
dual bound improvement produced by the branching constraint which is time-consuming to
evaluate in the context of column generation
Therefore, one can let the branching algorithm quickly estimate the score of each candidate 
and retain the most promising branching candidates. 
This is called a **phase**. The goal is to first evaluate a large number
of candidates with a very fast conquer algorithm and retain a certain number of promising ones. 
Then, over the phases, it evaluates the improvement with a more precise conquer algorithm and
restricts the number of retained candidates until only one is left.

### Strong Branching API

```@docs
Branching.get_units_to_restore_for_conquer
Branching.get_phases
Branching.get_score
Branching.get_conquer
Branching.get_max_nb_candidates
```

The following methods are part of the API but have a default implementation.
We advise you to not change them.

```@docs
Branching.perform_branching_phase!
Branching.eval_candidate!
Branching.eval_child_of_candidate!
```

#### Score

```@docs
Branching.AbstractBranchingScore
Branching.compute_score
```