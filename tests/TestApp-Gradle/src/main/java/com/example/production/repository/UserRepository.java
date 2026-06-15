package com.example.production.repository;

import com.example.production.model.User;
import org.springframework.stereotype.Repository;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Repository
public class UserRepository {
    private final Map<Long, User> store = new ConcurrentHashMap<>();
    private final AtomicLong idGen = new AtomicLong(1);

    public List<User> findAll() {
        return new ArrayList<>(store.values());
    }

    public Optional<User> findById(Long id) {
        return Optional.ofNullable(store.get(id));
    }

    public User save(User user) {
        if (user.getId() == null) {
            user.setId(idGen.getAndIncrement());
        }
        store.put(user.getId(), user);
        return user;
    }

    public Optional<User> update(Long id, User user) {
        if (!store.containsKey(id)) return Optional.empty();
        user.setId(id);
        store.put(id, user);
        return Optional.of(user);
    }

    public boolean delete(Long id) {
        return store.remove(id) != null;
    }

    public int count() {
        return store.size();
    }
}
