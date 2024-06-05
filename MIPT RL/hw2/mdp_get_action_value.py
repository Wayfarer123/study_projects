def get_action_value(mdp, state_values, state, action, gamma):
    """ Вычисляет Q(s,a) согласно формуле выше """
    
    # Ваша имплементация ниже
    q_value = 0
    for s, p in mdp.get_next_states(state, action).items():
        q_value += mdp.get_reward(state, action, s) * p + p * gamma * state_values[s]
    
    return q_value
