module discretemdp;

import mdp;
import discretefunctions;
import std.math;
import std.typecons;
import std.numeric;
import std.conv;

class State {


    abstract bool isTerminal();
}

class Action {


}

class Reward {

    abstract double opIndex(State s, Action a );

    abstract Function!(double, State, Action) toFunction();

}


class Model {

    abstract Set!(State) S();

    abstract Set!(Action) A();

    abstract ConditionalDistribution!(State, State, Action) T();

    abstract Function!(double, State, Action) R();

    abstract double gamma();

    abstract Distribution!(State) initialStateDistribution();
}


public Function!(double, State) value_iteration(Model m, double tolerance, int max_iter = int.max) {

    Function!(double, State) v_next;
    Function!(double, State) v_prev = max( m.R() );
    auto T = m.T().flatten();
    
    double diff = max( v_prev );
    int iter = 0;

    while (diff > tolerance*(1 - m.gamma()) / m.gamma() && iter < max_iter) {
        
        v_next = max( m.R() + m.gamma() * sumout!(State)( T * v_prev ) ) ;

        diff = max ( v_next - v_prev ); 
        v_prev = v_next;
    }

    return v_next;
}

public Function!(double, State, Action) q_value_iteration(Model m, double tolerance, int max_iter = int.max) {

    return sumout!(State) (m.T() * value_iteration(m, tolerance, max_iter) );
}

public Function!(Tuple!(Action), State) optimum_policy (Function!(double, State) V, Model m) {

    return argmax( sumout!(State)( m.T() * V ) );

}

public Function!(Tuple!(Action), State) optimum_policy (Function!(double, State, Action) Q) {

    return argmax( Q );

}

public Function!(Tuple!(Action), State) optimum_policy (Model m, double tolerance, int max_iter = int.max) {

    return argmax (q_value_iteration (m, tolerance, max_iter) );
}


public Sequence!(State, Action) simulate(Model m, int timesteps, Distribution!(State) initialStates) {

    return null;
    
}


class BasicModel : Model {

    protected Set!(State) states;
    protected Set!(Action) actions;
    protected ConditionalDistribution!(State, State, Action) transitions;
    protected Function!(double, State, Action) rewards;
    protected double gam;
    protected Distribution!(State) isd;
    
    public this(Set!(State) states, Set!(Action) actions, ConditionalDistribution!(State, State, Action) transitions, Function!(double, State, Action) rewards, double gamma, Distribution!(State) initialStateDistribution) {
        this.states = states;
        this.actions = actions;
        this.transitions = transitions;
        this.rewards = rewards;
        this.gam = gamma;
        this.isd = initialStateDistribution;
    }
    
    public override Set!(State) S() {
        return states;
    }

    public override Set!(Action) A() {
        return actions;
    }

    public override ConditionalDistribution!(State, State, Action) T() {
        return transitions;
    }

    public override Function!(double, State, Action) R() {
        return rewards;
    }

    public override double gamma() {
        return gam;
    }

    public override Distribution!(State) initialStateDistribution() {
        return isd;
    }
}


class LinearReward : Reward {

    protected double [] weights;
    protected Function!(double [], State, Action) features;
    protected size_t size;

    public this(Function!(double [], State, Action) f) {
        features = f;
        foreach(key ; f.param_set()) {
            size = f[key].length;
            break;
        }
    }

    public this(Function!(double [], State, Action) f, double [] weights) {
        this(f);
        setWeights(weights);
    }

    public size_t getSize() {
        return size;
    }
        
    public double [] getWeights() {
        return weights;
    }

    public void setWeights(double [] w) {
        if (w.length != size)
            throw new Exception("Incorrect weight size, the feature function is of size: " ~ to!string(size));
            
        weights = w;
    }

    public double [] getFeatures(State s, Action a) {
        return features[tuple(s, a)];
    }

    public override double opIndex(State s, Action a) {
        return dotProduct(weights, getFeatures(s, a));
    }
        
    public double opIndex(Tuple!(State, Action) t) {
        return dotProduct(weights, features[t]);
    }

    public override Function!(double, State, Action) toFunction() {

        auto returnval = new Function!(double, State, Action)(features.param_set(), 0.0);

        foreach (key; features.param_set()) {
            returnval[key] = opIndex(key);
        }

        return returnval;
    }
}
