package com.example.production.component;

import com.example.production.model.Product;
import com.example.production.model.User;
import com.example.production.repository.ProductRepository;
import com.example.production.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class AppStartupRunner implements CommandLineRunner {
	private static final Logger log = LoggerFactory.getLogger(AppStartupRunner.class);

	private final UserRepository userRepository;
	private final ProductRepository productRepository;

	public AppStartupRunner(UserRepository userRepository, ProductRepository productRepository) {
		this.userRepository = userRepository;
		this.productRepository = productRepository;
	}

	@Override
	public void run(String... args) {
		log.info("TestApp starting up — seeding demo data");

		userRepository.save(new User(null, "Alice", "alice@example.com", "ADMIN"));
		userRepository.save(new User(null, "Bob", "bob@example.com", "USER"));
		userRepository.save(new User(null, "Carol", "carol@example.com", "USER"));
		userRepository.save(new User(null, "Dave", "dave@example.com", "MODERATOR"));

		productRepository.save(new Product(null, "Widget", 9.99, true));
		productRepository.save(new Product(null, "Gadget", 24.99, true));
		productRepository.save(new Product(null, "Doohickey", 49.99, false));

		log.info("Seeded {} users and {} products", userRepository.count(), productRepository.count());
	}
}
