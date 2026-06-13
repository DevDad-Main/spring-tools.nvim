package com.example.production.service;

import com.example.production.model.User;
import com.example.production.repository.UserRepository;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;

@Service
public class UserService {
    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public List<User> getAllUsers() {
        return userRepository.findAll();
    }

    public Optional<User> getUserById(Long id) {
        return userRepository.findById(id);
    }

    public User createUser(User user) {
        return userRepository.save(user);
    }

    public Optional<User> updateUser(Long id, User user) {
        return userRepository.update(id, user);
    }

    public boolean deleteUser(Long id) {
        return userRepository.delete(id);
    }

    public int countUsers() {
        return userRepository.count();
    }
}
