CREATE TABLE `flair_override` (
  `user_id` bigint NOT NULL,
  `trade_thread_id` bigint NOT NULL,
  `override_text` varchar(255) NOT NULL,
  PRIMARY KEY (`user_id`,`trade_thread_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
