package com.example.production.controller;

import com.example.production.model.Product;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class ProductControllerTest {

    @Autowired
    private TestRestTemplate rest;

    private static Long createdId;

    @Test
    @Order(1)
    void createProduct() {
        var product = new Product(null, "TestProduct", 19.99, true);
        var response = rest.postForEntity("/api/products", product, Product.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getId()).isNotNull();
        createdId = response.getBody().getId();
    }

    @Test
    @Order(2)
    void getAllProducts() {
        var response = rest.getForEntity("/api/products", Product[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotEmpty();
    }

    @Test
    @Order(3)
    void getProductById() {
        var response = rest.getForEntity("/api/products/{id}", Product.class, createdId);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getName()).isEqualTo("TestProduct");
    }

    @Test
    @Order(4)
    void updateStock() {
        var request = new HttpEntity<>(Map.of("inStock", false));
        var response = rest.exchange("/api/products/{id}/stock", HttpMethod.PATCH, request, Product.class, createdId);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().isInStock()).isFalse();
    }

    @Test
    @Order(5)
    void deleteProduct() {
        var response = rest.exchange("/api/products/{id}", HttpMethod.DELETE, null, Void.class, createdId);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }
}
