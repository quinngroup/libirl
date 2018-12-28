module trajectories;

import discretefunctions;
import discretemdp;
import std.typecons;



// Takes in incomplete trajectories and computes the complete distribution over all possible trajectories
interface Sequence_Distribution_Computer(T ...) {

    public Sequence!(Distribution!(T))[] to_traj_distr( Sequence!(T)[] trajectories, double [] weights );
}


// Takes perfectly observed trajectories and converts them to trajectory distributions
class CompleteTrajectoryToTrajectoryDistr : Sequence_Distribution_Computer!(State, Action) {

    Set!(State) state_space;
    Set!(Action) action_space;
    bool extend_terminals_to_equal_length;
    
    public this(Set!(State) state_set, Set!(Action) action_set, bool extend_terminals_to_equal_length = true) {
        this.state_space = state_set;
        this.action_space = action_set;
        this.extend_terminals_to_equal_length = extend_terminals_to_equal_length;
    }

    public Sequence!(Distribution!(State, Action))[] to_traj_distr( Sequence!(State, Action)[] trajectories, double [] weights ) {

        Sequence!(Distribution!(State, Action))[] returnval = new Sequence!(Distribution!(State, Action))[trajectories.length];

        auto full_space = state_space.cartesian_product(action_space);
        size_t max_traj_length = 0;
        foreach (t ; trajectories)
            if (t.length() > max_traj_length)
                max_traj_length = t.length();
        
        foreach(i, traj ; trajectories) {

            Sequence!(Distribution!(State, Action)) seq = new Sequence!(Distribution!(State, Action))(traj.length());
            foreach(t, timestep ; traj) {
                Distribution!(State, Action) dist = new Distribution!(State, Action)(full_space, 0.0);

            
                if (timestep[0].isTerminal() && timestep[1] is null) {
                    // In this case, we're missing the action for the terminal state
                    // fix this by making all actions equally likely
                    foreach (a ; action_space) {
                        dist[tuple(timestep[0], a[0])] = 1.0 / action_space.size();
                    }
                    
                } else {
                    dist[timestep] = 1.0;
                }

                seq[t] = tuple(dist);
            }

            if (traj[$][0].isTerminal() && extend_terminals_to_equal_length ) {

                while( seq.length() < max_traj_length) {
                    seq ~= seq[$];
                }
            }
            
            returnval[i] = seq;
        }

        return returnval;

    }

}

// convenience, since these types of trajectories are generated by so many tests
public Sequence!(Distribution!(State, Action))[] traj_to_traj_distr( Sequence!(State, Action)[] trajectories, Model m, bool extend_to_equal_lengths = true) {

    CompleteTrajectoryToTrajectoryDistr converter = new CompleteTrajectoryToTrajectoryDistr(m.S(), m.A());

    return converter.to_traj_distr(trajectories, null);
    
}


// Takes partial trajectories and converts them to trajectory distributions
// Exact version, interates through all possible trajectories using a forward-backword algorithm
class ExactPartialTrajectoryToTrajectoryDistr : Sequence_Distribution_Computer!(State, Action) {

    protected bool extend_terminals_to_equal_length;
    protected Model m;
    protected LinearReward r;
    
    public this(Model m, LinearReward r, bool extend_terminals_to_equal_length = true) {
        this.extend_terminals_to_equal_length = extend_terminals_to_equal_length;
        this.m = m;
        this.r = r;
    }

    public Sequence!(Distribution!(State, Action))[] to_traj_distr( Sequence!(State, Action)[] trajectories, double [] weights ) {

        r.setWeights(weights);
        m.setR(r.toFunction());
        
        auto policy = m.getPolicy();

        auto full_space = m.S().cartesian_product(m.A());
        
        Sequence!(Distribution!(State, Action))[] forward = new Sequence!(Distribution!(State, Action))[trajectories.length];

        size_t max_traj_length = 0;
        foreach (t ; trajectories)
            if (t.length() > max_traj_length)
                max_traj_length = t.length();

        // forward step
        foreach(i, traj ; trajectories) {

            Sequence!(Distribution!(State, Action)) seq = new Sequence!(Distribution!(State, Action))(traj.length());
            foreach(t, timestep ; traj) {
                Distribution!(State, Action) dist;

                if (timestep[0] is null) {
                    // state is missing
                    if (t == 0) {
                        // first timestep, use initial state distribution
                        dist = forward_timestep(policy * m.initialStateDistribution(), policy, t);
                    } else {
                        dist = forward_timestep(seq[t-1][0], policy, t);
                    }
                    
                } else if (timestep[1] is null) {
                    // action is missing
                    auto temp_state_dist = new Distribution!(State)(m.S(), 0.0);
                    temp_state_dist[timestep[0]] = 1.0;
                    dist = policy * temp_state_dist;
                    
                } else {
                    // neither are missing
                    dist = new Distribution!(State, Action)(full_space, 0.0);
                    dist[timestep] = 1.0;
                }

                seq[t] = tuple(dist);
            }

            if (traj[$][0] ! is null && traj[$][0].isTerminal() && extend_terminals_to_equal_length ) {

                while( seq.length() < max_traj_length) {
                    seq ~= seq[$];
                }
            }
            
            forward[i] = seq;
        }
        
        Sequence!(Distribution!(State, Action))[] reverse = new Sequence!(Distribution!(State, Action))[trajectories.length];
        // reverse step
        foreach(i, traj ; trajectories) {
            Sequence!(Distribution!(State, Action)) seq = new Sequence!(Distribution!(State, Action))(traj.length());
            seq[$] = tuple(new Distribution!(State, Action)(full_space, 1.0));
            
            foreach_reverse(t, timestep ; traj) {

                if (trajectories[i].length > t) {

                    Distribution!(State, Action) dist;

                    if (timestep[0] is null) {
                        // state is missing
                        auto temp = policy * new Distribution!(State)(m.S(), DistInitType.Uniform);
                        if (t < traj.length - 1) {
                            dist = reverse_timestep(temp, seq[t+1][0], t);
                        } else {
                            dist = reverse_timestep(temp, new Distribution!(State, Action)(full_space, 1.0), t);
                        }        
                    } else if (timestep[1] is null) {
                        // action is missing
                        auto temp_state_dist = new Distribution!(State)(m.S(), 0.0);
                        temp_state_dist[timestep[0]] = 1.0;
                        dist = policy * temp_state_dist;
                    
                    } else {
                        // neither are missing
                        dist = new Distribution!(State, Action)(full_space, 0.0);
                        dist[timestep] = 1.0;
                    }

                    seq[t] = tuple(dist);
                }
                if (traj[$][0] ! is null && traj[$][0].isTerminal() && extend_terminals_to_equal_length ) {

                    while( seq.length() < max_traj_length) {
                        seq ~= seq[$];
                    }
                }
            }
            reverse[i] = seq;            
            
        }

        Sequence!(Distribution!(State, Action))[] returnval = new Sequence!(Distribution!(State, Action))[trajectories.length];

        // combine together
        foreach(i, traj ; forward) {
            returnval[i] = new Sequence!(Distribution!(State, Action))(traj.length());
            foreach( t, timestep; traj) {
                returnval[i][t] = tuple(new Distribution!(State, Action)(timestep[0] * reverse[i][t][0]));
                returnval[i][t][0].normalize();
            }
        }
        
        return returnval;

    }
    
    protected Distribution!(State, Action) forward_timestep(Distribution!(State, Action) previous_timestep, ConditionalDistribution!(Action, State) policy, size_t timestep) {

        auto returnval = policy * new Distribution!(State)(sumout!(Action)(sumout!(State)( (m.T() * previous_timestep).reverse_params())));
//        returnval.normalize();        
        return returnval;

    }

    protected Distribution!(State, Action) reverse_timestep(Distribution!(State, Action) current_timestep, Distribution!(State, Action) next_timestep, size_t timestep) {
        auto returnval = new Distribution!(State, Action)(sumout!(State)( ((m.T() * current_timestep) * sumout!(Action)(next_timestep ) ) ) );
//        returnval.normalize();
        return returnval;
    }
}

Sequence!(Distribution!(T)) SequenceMarkovChainSmoother(T)(Sequence!(Distribution!(T)) observations, ConditionalDistribution!(T, T) transitions, Distribution!(T) initial_state) {

    
    Sequence!(Distribution!(T)) forward = new Sequence!(Distribution!(T))(observations.length);

    // forward step

    foreach(t, o_t; observations) {

        Distribution!(T) prior;
        
        if (t == 0) {
            prior = initial_state;
        } else {
            prior = forward[t-1][0];
        }
        forward[t] = tuple(new Distribution!(T)(sumout((transitions * prior).reverse_params()) * o_t[0]));        
    }
    // backward step

    Sequence!(Distribution!(T)) backward = new Sequence!(Distribution!(T))(observations.length);

    backward[$] = tuple(new Distribution!(T)(observations[$][0].param_set(), 1.0));
    foreach_reverse(t, o_t; observations) {

        if (t > 0) {
            backward[t-1] = tuple(new Distribution!(T)((sumout(((transitions.flatten() * o_t[0]) * backward[t][0]))) ));
        }
    }

    Sequence!(Distribution!(T)) returnval = new Sequence!(Distribution!(T))(observations.length);

    foreach(t, f_t ; forward) {
        returnval[t] = tuple(new Distribution!(T)(f_t[0] * backward[t][0]));
        returnval[t][0].normalize();
    }
    
    return returnval;

    
}


// alternative to my implementation using a markov smoother
class MarkovSmootherExactPartialTrajectoryToTrajectoryDistr: Sequence_Distribution_Computer!(State, Action) {

    bool extend_terminals_to_equal_length;
    Model m;
    LinearReward r;
    
    public this(Model m, LinearReward r, bool extend_terminals_to_equal_length = true) {
        this.extend_terminals_to_equal_length = extend_terminals_to_equal_length;
        this.m = m;
        this.r = r;
    }

    public Sequence!(Distribution!(State, Action))[] to_traj_distr( Sequence!(State, Action)[] trajectories, double [] weights ) {

        r.setWeights(weights);
        m.setR(r.toFunction());
        
        auto policy = m.getPolicy();

        auto full_space = m.S().cartesian_product(m.A());        
        auto tuple_full_space = pack_set(full_space);

        Sequence!(Distribution!(State, Action))[] returnval = new Sequence!(Distribution!(State, Action))[trajectories.length];

        auto temporary = new Distribution!(State)(m.S(), DistInitType.Uniform);
        auto missing_observation = pack_distribution(policy * temporary);
                    
        foreach (i, traj ; trajectories) {
            
            // build an observation sequence

             Sequence!(Distribution!(Tuple!(State, Action))) observations = new Sequence!(Distribution!(Tuple!(State, Action)))(traj.length);
             foreach( t, timestep; traj) {

                Distribution!(Tuple!(State, Action)) dist;

                if (timestep[0] is null) {
                    // state is missing
                    dist = missing_observation;
                   
                } else if (timestep[1] is null) {
                    // action is missing
                    auto temp_state_dist = new Distribution!(State)(m.S(), 0.0);
                    temp_state_dist[timestep[0]] = 1.0;
                    dist = pack_distribution(policy * temp_state_dist);
                    
                } else {
                    // neither are missing
                    dist = new Distribution!(Tuple!(State, Action))(tuple_full_space, 0.0);
                    dist[timestep] = 1.0;
                }
                

                observations[t] = tuple(dist);
             }

             
            // build a transition function
            
            auto transitions = new ConditionalDistribution!(Tuple!(State, Action), Tuple!(State, Action))(tuple_full_space, tuple_full_space);
            foreach (sa ; full_space) {
                transitions[sa] = pack_distribution( policy * m.T()[sa] );
                
            }

            Distribution!(Tuple!(State, Action)) initial_state = pack_distribution(policy * m.initialStateDistribution());
            
            auto temp_sequence = SequenceMarkovChainSmoother!(Tuple!(State, Action))(observations, transitions, initial_state);
            auto results = new Sequence!(Distribution!(State, Action))(temp_sequence.length);

            foreach (t, timestep; temp_sequence) {
                results[t] = tuple(unpack_distribution(timestep[0]));
            }
            returnval[i] = results;
        }

        return returnval;                
    }

}
