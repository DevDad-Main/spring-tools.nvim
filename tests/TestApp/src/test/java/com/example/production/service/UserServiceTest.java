package com.example.production.service;

import com.example.production.model.User;
import com.example.production.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    private UserService userService;

    @BeforeEach
    void setUp() {
        userService = new UserService(userRepository);
    }

    @Test
    void getAllUsers() {
        when(userRepository.findAll()).thenReturn(List.of(
                new User(1L, "Alice", "alice@test.com", "ADMIN"),
                new User(2L, "Bob", "bob@test.com", "USER")
        ));
        var users = userService.getAllUsers();
        assertThat(users).hasSize(2);
    }

    @Test
    void getUserByIdFound() {
        var user = new User(1L, "Alice", "alice@test.com", "ADMIN");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        var result = userService.getUserById(1L);
        assertThat(result).isPresent();
        assertThat(result.get().getName()).isEqualTo("Alice");
    }

    @Test
    void getUserByIdNotFound() {
        when(userRepository.findById(999L)).thenReturn(Optional.empty());
        var result = userService.getUserById(999L);
        assertThat(result).isEmpty();
    }

    @Test
    void createUser() {
        var input = new User(null, "NewUser", "new@test.com", "USER");
        var saved = new User(1L, "NewUser", "new@test.com", "USER");
        when(userRepository.save(any())).thenReturn(saved);
        var result = userService.createUser(input);
        assertThat(result.getId()).isEqualTo(1L);
    }

    @Test
    void deleteUserReturnsTrue() {
        when(userRepository.delete(1L)).thenReturn(true);
        assertThat(userService.deleteUser(1L)).isTrue();
    }
}
