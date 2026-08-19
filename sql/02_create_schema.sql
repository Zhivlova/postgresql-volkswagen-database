-- ============================================================
-- Volkswagen database schema
--
-- Целевая база данных: volkswagen
-- Скрипт запускается после подключения к базе "volkswagen".
-- PostgreSQL
-- ============================================================


-- ============================================================
-- Types
-- ============================================================

CREATE TYPE transmission_type AS ENUM (
    'automatic',
    'manual',
    'robot',
    'DSG'
);

CREATE TYPE engine_type AS ENUM (
    'petrol',
    'diesel',
    'hybrid',
    'electric'
);

CREATE TYPE category_type AS ENUM (
    'new',
    'used'
);

CREATE TYPE body_type AS ENUM (
    'coupe',
    'wagon',
    'sedan',
    'suv',
    'hatchback',
    'convertible'
);


-- ============================================================
-- Common updated_at trigger
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


-- ============================================================
-- Cars
-- ============================================================

CREATE TABLE cars (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    vin VARCHAR(17) NOT NULL UNIQUE,

    pts CHAR(15) NOT NULL UNIQUE,

    CONSTRAINT chk_cars_vin
        CHECK (vin ~ '^[A-HJ-NPR-Z0-9]{17}$'),

    CONSTRAINT chk_cars_pts
        CHECK (pts ~ '^[0-9]{15}$')
);


-- ============================================================
-- Profiles
-- ============================================================

CREATE TABLE profiles (
    car_id BIGINT PRIMARY KEY,

    model VARCHAR(100),

    date_of_production DATE,

    category category_type,

    color VARCHAR(100),

    bodywork body_type,

    price NUMERIC(12, 2) NOT NULL,

    transmission transmission_type,

    engine engine_type,

    engine_volume INTEGER,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_profiles_car
        FOREIGN KEY (car_id)
        REFERENCES cars(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_profiles_model
        CHECK (
            model IS NULL
            OR length(trim(model)) > 0
        ),

    CONSTRAINT chk_profiles_price
        CHECK (price >= 0),

    CONSTRAINT chk_profiles_engine_volume
        CHECK (
            engine_volume IS NULL
            OR engine_volume > 0
        )
);

CREATE TRIGGER trg_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- ============================================================
-- Dealers
-- ============================================================

CREATE TABLE dealers (
    dealer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    dealer_name VARCHAR(50) NOT NULL UNIQUE,

    dealer_showroom_address VARCHAR(100) NOT NULL,

    dealer_phone VARCHAR(16) NOT NULL,

    dealer_email VARCHAR(100) NOT NULL,

    CONSTRAINT chk_dealers_name
        CHECK (length(trim(dealer_name)) > 0),

    CONSTRAINT chk_dealers_showroom_address
        CHECK (length(trim(dealer_showroom_address)) > 0),

    CONSTRAINT chk_dealers_phone
        CHECK (dealer_phone ~ '^\+[1-9][0-9]{7,14}$'),

    CONSTRAINT chk_dealers_email
        CHECK (
            dealer_email ~
            '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
        )
);


-- ============================================================
-- Cars <-> Dealers
-- ============================================================

CREATE TABLE cars_dealers (
    car_id BIGINT NOT NULL,

    dealer_id BIGINT NOT NULL,

    PRIMARY KEY (car_id, dealer_id),

    CONSTRAINT fk_cars_dealers_car
        FOREIGN KEY (car_id)
        REFERENCES cars(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cars_dealers_dealer
        FOREIGN KEY (dealer_id)
        REFERENCES dealers(dealer_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_cars_dealers_dealer_id
    ON cars_dealers(dealer_id);


-- ============================================================
-- Photo albums
-- ============================================================

CREATE TABLE photo_albums (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    name VARCHAR(255) NOT NULL,

    car_id BIGINT NOT NULL,

    CONSTRAINT fk_photo_albums_car
        FOREIGN KEY (car_id)
        REFERENCES cars(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_photo_albums_name
        CHECK (length(trim(name)) > 0),

    -- Составной ключ необходим для контроля принадлежности
    -- альбома и media одному и тому же автомобилю.
    CONSTRAINT uq_photo_albums_id_car
        UNIQUE (id, car_id)
);

CREATE INDEX idx_photo_albums_car_id
    ON photo_albums(car_id);


-- ============================================================
-- Media types
-- ============================================================

CREATE TABLE media_types (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    name VARCHAR(255) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_media_types_name
        CHECK (length(trim(name)) > 0)
);

CREATE TRIGGER trg_media_types_updated_at
BEFORE UPDATE ON media_types
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- ============================================================
-- Media
--
-- storage_key содержит путь / ключ объекта в S3.
-- ============================================================

CREATE TABLE media (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    media_type_id BIGINT NOT NULL,

    car_id BIGINT NOT NULL,

    storage_key TEXT NOT NULL,

    filename TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_media_car
        FOREIGN KEY (car_id)
        REFERENCES cars(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_media_type
        FOREIGN KEY (media_type_id)
        REFERENCES media_types(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_media_storage_key
        CHECK (length(trim(storage_key)) > 0),

    -- Составной ключ необходим для контроля принадлежности
    -- media и альбома одному и тому же автомобилю.
    CONSTRAINT uq_media_id_car
        UNIQUE (id, car_id)
);

CREATE INDEX idx_media_car_id
    ON media(car_id);

CREATE INDEX idx_media_media_type_id
    ON media(media_type_id);

CREATE TRIGGER trg_media_updated_at
BEFORE UPDATE ON media
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- ============================================================
-- Album <-> Media
--
-- Связь media с альбомами.
-- car_id используется для обеспечения целостности данных:
-- media одного автомобиля нельзя добавить в альбом другого.
-- ============================================================

CREATE TABLE album_media (
    album_id BIGINT NOT NULL,

    car_id BIGINT NOT NULL,

    media_id BIGINT NOT NULL,

    PRIMARY KEY (album_id, media_id),

    CONSTRAINT fk_album_media_album
        FOREIGN KEY (album_id, car_id)
        REFERENCES photo_albums(id, car_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_album_media_media
        FOREIGN KEY (media_id, car_id)
        REFERENCES media(id, car_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_album_media_media_id
    ON album_media(media_id);

CREATE INDEX idx_album_media_car_id
    ON album_media(car_id);


-- ============================================================
-- Services
-- ============================================================

CREATE TABLE services (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    service_name VARCHAR(255) NOT NULL UNIQUE,

    CONSTRAINT chk_services_service_name
        CHECK (length(trim(service_name)) > 0)
);


-- ============================================================
-- Cars <-> Services
-- ============================================================

CREATE TABLE cars_services (
    car_id BIGINT NOT NULL,

    service_id BIGINT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (car_id, service_id),

    CONSTRAINT fk_cars_services_car
        FOREIGN KEY (car_id)
        REFERENCES cars(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cars_services_service
        FOREIGN KEY (service_id)
        REFERENCES services(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_cars_services_service_id
    ON cars_services(service_id);


-- ============================================================
-- Clients
-- ============================================================

CREATE TABLE clients (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    firstname VARCHAR(50) NOT NULL,

    lastname VARCHAR(50) NOT NULL,

    email VARCHAR(120),

    phone VARCHAR(16) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_clients_firstname
        CHECK (length(trim(firstname)) > 0),

    CONSTRAINT chk_clients_lastname
        CHECK (length(trim(lastname)) > 0),

    CONSTRAINT chk_clients_phone
        CHECK (phone ~ '^\+[1-9][0-9]{7,14}$')
);

CREATE INDEX idx_clients_email
    ON clients(email);

CREATE INDEX idx_clients_phone
    ON clients(phone);

CREATE TRIGGER trg_clients_updated_at
BEFORE UPDATE ON clients
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- ============================================================
-- Cars <-> Clients
--
-- Один клиент может быть связан с несколькими автомобилями,
-- а один автомобиль — с несколькими клиентами.
--
-- Например, собственник автомобиля и другой человек,
-- который может привезти этот автомобиль на обслуживание.
-- ============================================================

CREATE TABLE cars_clients (
    car_id BIGINT NOT NULL,

    client_id BIGINT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (car_id, client_id),

    CONSTRAINT fk_cars_clients_car
        FOREIGN KEY (car_id)
        REFERENCES cars(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cars_clients_client
        FOREIGN KEY (client_id)
        REFERENCES clients(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_cars_clients_client_id
    ON cars_clients(client_id);

CREATE TRIGGER trg_cars_clients_updated_at
BEFORE UPDATE ON cars_clients
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- ============================================================
-- Features
-- ============================================================

CREATE TABLE features (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    feature_name VARCHAR(255) NOT NULL UNIQUE,

    CONSTRAINT chk_features_feature_name
        CHECK (length(trim(feature_name)) > 0)
);


-- ============================================================
-- Cars <-> Features
-- ============================================================

CREATE TABLE cars_features (
    car_id BIGINT NOT NULL,

    feature_id BIGINT NOT NULL,

    PRIMARY KEY (car_id, feature_id),

    CONSTRAINT fk_cars_features_car
        FOREIGN KEY (car_id)
        REFERENCES cars(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_cars_features_feature
        FOREIGN KEY (feature_id)
        REFERENCES features(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_cars_features_feature_id
    ON cars_features(feature_id);


-- ============================================================
-- Documentation
-- ============================================================

-- ============================================================
-- Types
-- ============================================================

COMMENT ON TYPE transmission_type IS
'Тип коробки передач автомобиля';

COMMENT ON TYPE engine_type IS
'Тип топлива автомобиля';

COMMENT ON TYPE category_type IS
'Категория автомобиля по состоянию';

COMMENT ON TYPE body_type IS
'Тип кузова автомобиля';


-- ============================================================
-- Common function
-- ============================================================

COMMENT ON FUNCTION update_updated_at_column() IS
'Триггерная функция для автоматического обновления поля updated_at';


-- ============================================================
-- Cars
-- ============================================================

COMMENT ON TABLE cars IS
'Основная сущность автомобиля, идентифицируемая VIN и PTS';

COMMENT ON COLUMN cars.id IS
'Внутренний уникальный идентификатор автомобиля';

COMMENT ON COLUMN cars.vin IS
'17-символьный идентификационный номер автомобиля (VIN)';

COMMENT ON COLUMN cars.pts IS
'15-значный номер ПТС';


-- ============================================================
-- Profiles
-- ============================================================

COMMENT ON TABLE profiles IS
'Технические и описательные характеристики автомобиля, вынесенные отдельно для уменьшения размера основной сущности cars';

COMMENT ON COLUMN profiles.car_id IS
'Идентификатор автомобиля, для которого задан профиль';

COMMENT ON COLUMN profiles.model IS
'Модель автомобиля';

COMMENT ON COLUMN profiles.date_of_production IS
'Дата производства автомобиля';

COMMENT ON COLUMN profiles.category IS
'Категория автомобиля: новый или подержанный';

COMMENT ON COLUMN profiles.color IS
'Цвет кузова автомобиля';

COMMENT ON COLUMN profiles.bodywork IS
'Тип кузова автомобиля';

COMMENT ON COLUMN profiles.price IS
'Текущая цена автомобиля';

COMMENT ON COLUMN profiles.transmission IS
'Тип коробки передач';

COMMENT ON COLUMN profiles.engine IS
'Тип топлива';

COMMENT ON COLUMN profiles.engine_volume IS
'Рабочий объём двигателя в кубических сантиметрах; NULL для автомобилей без двигателя внутреннего сгорания';

COMMENT ON COLUMN profiles.created_at IS
'Дата и время создания профиля';

COMMENT ON COLUMN profiles.updated_at IS
'Дата и время последнего изменения профиля';


-- ============================================================
-- Dealers
-- ============================================================

COMMENT ON TABLE dealers IS
'Дилеры Volkswagen и их контактная информация';

COMMENT ON COLUMN dealers.dealer_id IS
'Внутренний уникальный идентификатор дилера';

COMMENT ON COLUMN dealers.dealer_name IS
'Название дилера';

COMMENT ON COLUMN dealers.dealer_showroom_address IS
'Адрес дилерского шоурума';

COMMENT ON COLUMN dealers.dealer_phone IS
'Телефон дилера в нормализованном формате E.164';

COMMENT ON COLUMN dealers.dealer_email IS
'Контактный email дилера';


-- ============================================================
-- Cars <-> Dealers
-- ============================================================

COMMENT ON TABLE cars_dealers IS
'Связь многие-ко-многим между автомобилями и дилерами';

COMMENT ON COLUMN cars_dealers.car_id IS
'Идентификатор автомобиля';

COMMENT ON COLUMN cars_dealers.dealer_id IS
'Идентификатор дилера';


-- ============================================================
-- Photo albums
-- ============================================================

COMMENT ON TABLE photo_albums IS
'Альбомы фотографий и других медиафайлов конкретного автомобиля';

COMMENT ON COLUMN photo_albums.id IS
'Внутренний уникальный идентификатор альбома';

COMMENT ON COLUMN photo_albums.name IS
'Название альбома';

COMMENT ON COLUMN photo_albums.car_id IS
'Идентификатор автомобиля, которому принадлежит альбом';


-- ============================================================
-- Media types
-- ============================================================

COMMENT ON TABLE media_types IS
'Справочник типов медиафайлов, например изображение или видео';

COMMENT ON COLUMN media_types.id IS
'Внутренний уникальный идентификатор типа медиа';

COMMENT ON COLUMN media_types.name IS
'Название типа медиафайла';


-- ============================================================
-- Media
-- ============================================================

COMMENT ON TABLE media IS
'Медиафайлы, связанные с автомобилями; содержимое файлов хранится во внешнем объектном хранилище S3';

COMMENT ON COLUMN media.id IS
'Внутренний уникальный идентификатор медиафайла';

COMMENT ON COLUMN media.media_type_id IS
'Идентификатор типа медиафайла';

COMMENT ON COLUMN media.car_id IS
'Идентификатор автомобиля, которому принадлежит медиафайл';

COMMENT ON COLUMN media.storage_key IS
'Ключ или путь объекта в S3, используемый для получения файла';

COMMENT ON COLUMN media.filename IS
'Исходное или отображаемое имя файла';

COMMENT ON COLUMN media.created_at IS
'Дата и время создания записи о медиафайле';

COMMENT ON COLUMN media.updated_at IS
'Дата и время последнего изменения записи о медиафайле';


-- ============================================================
-- Album <-> Media
-- ============================================================

COMMENT ON TABLE album_media IS
'Связь многие-ко-многим между альбомами и медиафайлами с дополнительным контролем принадлежности одному автомобилю';

COMMENT ON COLUMN album_media.album_id IS
'Идентификатор альбома';

COMMENT ON COLUMN album_media.car_id IS
'Идентификатор автомобиля; используется для контроля согласованности альбома и медиафайла';

COMMENT ON COLUMN album_media.media_id IS
'Идентификатор медиафайла';


-- ============================================================
-- Services
-- ============================================================

COMMENT ON TABLE services IS
'Справочник услуг, которые могут быть связаны с автомобилями';

COMMENT ON COLUMN services.id IS
'Внутренний уникальный идентификатор услуги';

COMMENT ON COLUMN services.service_name IS
'Название услуги';


-- ============================================================
-- Cars <-> Services
-- ============================================================

COMMENT ON TABLE cars_services IS
'Связь многие-ко-многим между автомобилями и услугами';

COMMENT ON COLUMN cars_services.car_id IS
'Идентификатор автомобиля';

COMMENT ON COLUMN cars_services.service_id IS
'Идентификатор услуги';

COMMENT ON COLUMN cars_services.created_at IS
'Дата и время создания связи автомобиля с услугой';


-- ============================================================
-- Clients
-- ============================================================

COMMENT ON TABLE clients IS
'Клиенты, связанные с автомобилями и обслуживанием';

COMMENT ON COLUMN clients.id IS
'Внутренний уникальный идентификатор клиента';

COMMENT ON COLUMN clients.firstname IS
'Имя клиента';

COMMENT ON COLUMN clients.lastname IS
'Фамилия клиента';

COMMENT ON COLUMN clients.email IS
'Email клиента; один email может использоваться несколькими клиентами';

COMMENT ON COLUMN clients.phone IS
'Телефон клиента в нормализованном формате E.164';

COMMENT ON COLUMN clients.created_at IS
'Дата и время создания клиента';

COMMENT ON COLUMN clients.updated_at IS
'Дата и время последнего изменения данных клиента';


-- ============================================================
-- Cars <-> Clients
-- ============================================================

COMMENT ON TABLE cars_clients IS
'Связь многие-ко-многим между автомобилями и клиентами';

COMMENT ON COLUMN cars_clients.car_id IS
'Идентификатор автомобиля';

COMMENT ON COLUMN cars_clients.client_id IS
'Идентификатор клиента, связанного с автомобилем';

COMMENT ON COLUMN cars_clients.created_at IS
'Дата и время создания связи автомобиля с клиентом';

COMMENT ON COLUMN cars_clients.updated_at IS
'Дата и время последнего изменения связи автомобиля с клиентом';


-- ============================================================
-- Features
-- ============================================================

COMMENT ON TABLE features IS
'Справочник характеристик и дополнительного оборудования автомобилей';

COMMENT ON COLUMN features.id IS
'Внутренний уникальный идентификатор характеристики';

COMMENT ON COLUMN features.feature_name IS
'Название характеристики или дополнительного оборудования';


-- ============================================================
-- Cars <-> Features
-- ============================================================

COMMENT ON TABLE cars_features IS
'Связь многие-ко-многим между автомобилями и их характеристиками';

COMMENT ON COLUMN cars_features.car_id IS
'Идентификатор автомобиля';

COMMENT ON COLUMN cars_features.feature_id IS
'Идентификатор характеристики автомобиля';