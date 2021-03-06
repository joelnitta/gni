class CreateCanonicalForms < ActiveRecord::Migration
  def up
    execute "CREATE TABLE `canonical_forms` (
      `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
      `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
      `first_letter` char(1) NOT NULL,
      `length` int(11) NOT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `idx_canonical_forms_1` (`name`),
      KEY `idx_canonical_forms_2` (`first_letter`,`length`)
    ) ENGINE=InnoDB DEFAULT CHARSET=ascii COLLATE=ascii_general_ci"
  end

  def down
    drop_table :canonical_forms
  end
end
