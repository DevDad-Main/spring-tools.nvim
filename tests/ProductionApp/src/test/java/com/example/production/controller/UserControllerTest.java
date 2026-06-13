package com.example.production.controller;

import com.example.production.model.User;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class UserControllerTest {

    @Autowired
    private TestRestTemplate rest;

    private static Long createdId;

    @Test
    @Order(1)
    void createUser() {
        var user = new User(null, "TestUser", "test@example.com", "USER");
        var response = rest.postForEntity("/api/users", user, User.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getId()).isNotNull();
        createdId = response.getBody().getId();
    }

    @Test
    @Order(2)
    void getAllUsers() {
        var response = rest.getForEntity("/api/users", User[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotEmpty();
    }

    @Test
    @Order(3)
    void getUserById() {
        var response = rest.getForEntity("/api/users/{id}", User.class, createdId);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getName()).isEqualTo("TestUser");
    }

    @Test
    @Order(4)
    void getUserByIdNotFound() {
        var response = rest.getForEntity("/api/users/{id}", User.class, 99999L);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @Order(5)
    void updateUser() {
        var updated = new User(null, "UpdatedName", "updated@example.com", "ADMIN");
        var request = new HttpEntity<>(updated);
        var response = rest.exchange("/api/users/{id}", HttpMethod.PUT, request, User.class, createdId);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getName()).isEqualTo("UpdatedName");
    }

    @Test
    @Order(6)
    void deleteUser() {
        var response = rest.exchange("/api/users/{id}", HttpMethod.DELETE, null, Void.class, createdId);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }
}
