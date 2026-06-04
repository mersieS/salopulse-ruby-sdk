# Salopulse Ruby SDK

Otomatik SQL, hata ve HTTP performans telemetrisi — Ruby uygulamaları için Salopulse APM istemcisi.

## Kurulum

```ruby
# Gemfile
gem "salopulse"
```

```
bundle install
```

## Hızlı Başlangıç

```ruby
# config/initializers/salopulse.rb
Salopulse.init(dsn: ENV["SALOPULSE_DSN"])
```

Rails varsa bu kadarı yeter — middleware ve ActiveRecord aboneliği otomatik kurulur.

## Otomatik Yakalanan Olaylar

- **SQL** — `ActiveSupport::Notifications` üzerinden her sorgu (schema/transaction/cached hariç)
- **Hata** — Rack middleware'den sızan tüm exception'lar
- **Performans** — Her HTTP request için süre + status

## Manuel API

```ruby
Salopulse.capture_exception(error, user_context: { user_id: 1 })
Salopulse.capture_message("cache miss", level: :warning)
Salopulse.set_user(id: 1, email: "a@b.com")
Salopulse.set_tag(:feature, "checkout-v2")
Salopulse.flush(timeout: 5)
Salopulse.close
```

## Konfigürasyon

| Seçenek            | Varsayılan | Açıklama                                       |
|--------------------|------------|------------------------------------------------|
| `dsn`              | —          | **Zorunlu.** `https://api_key@host` formatı    |
| `release`          | `nil`      | Sürüm etiketi (genelde git SHA)                |
| `environment`      | `nil`      | `production` / `staging` / ...                 |
| `sample_rate`      | `1.0`      | 0..1 arası örnekleme oranı                     |
| `flush_interval`   | `5` sn     | Background flush periyodu                      |
| `flush_batch_size` | `100`      | Tek POST'ta gönderilen event sayısı            |
| `n1_threshold`     | `10`       | Aynı fingerprint kaç defadan sonra N+1 sayılır |
| `max_buffer_size`  | `10_000`   | Buffer üst sınırı; aşılırsa silent drop        |
| `before_send`      | `nil`      | `->(event) { event }`; `nil` dönerse atılır    |
| `logger`           | stdout     | SDK iç logları için                            |
| `enabled`          | `true`     | `false` → SDK tamamen no-op                    |

## Gizlilik

SDK aşağıdaki alanları otomatik maskeler (`[FILTERED]`):

- `password`, `password_confirmation`, `token`, `api_key`, `secret`
- `access_token`, `refresh_token`, `authorization`, `cookie`
- `credit_card`, `card_number`, `cvv`, `ssn`
- Header'lar: `Authorization`, `Cookie`, `X-Api-Key`, `X-Auth-Token`

## Performans

- Tüm I/O background thread'inde — istek path'i bloklanmaz
- Buffer üst sınırlı (`max_buffer_size`); patlayıp uygulamayı çökertmez
- Transport hatalarında exponential backoff retry (max 3) — başarısızsa event düşer, uygulamaya hata sızmaz

## Geliştirme

```
bundle install
bundle exec rspec
```

## Lisans

MIT
