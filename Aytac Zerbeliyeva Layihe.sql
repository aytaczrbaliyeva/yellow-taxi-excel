-- 1. Əvvəlcə normal mənzərəni gör: son 12 ayda hər anbar üzrə ləğv
--    edilməmiş sifariş sayı və ümumi dövriyyə.
-- Cədvəllər: warehouse, orders
-- Filtr: order_status <> 'CANCELLED' və order_date son 12 ay
-- Nəticə: warehouse_id, warehouse_name, order_count, total_revenue
-- >>> Bu sual sadədir, amma nəticəni yadda saxla: hansı anbar ən böyükdür?
--     Sonrakı suallarda "çox itki" ilə "böyük anbar"ı qarışdırmamaq üçün lazımdır.
select
    w.warehouse_id,
    w.warehouse_name,
    count(o.order_id) order_count,
    sum(o.total_amount)total_revenue
from warehouse w join orders o
on w.warehouse_id=o.warehouse_id
where o.order_status <> 'CANCELLED' and o.order_date >= add_months(trunc(sysdate),-12)
group by w.warehouse_id,w.warehouse_name
order by total_revenue desc;

-- 2. İndi inventarizasiya nəticələrinə bax. Hər anbar üzrə neçə sayım
--    qeydi var, ümumi miqdar fərqi və həmin fərqin pul dəyəri nə qədərdir?
-- Cədvəllər: stock_count, warehouse, product
-- Fərq = counted_qty - system_qty (mənfi rəqəm = mal əskikdir)
-- Sıralama: pul fərqi artan (ən böyük itki yuxarıda).
-- Nəticə: warehouse_id, warehouse_name, count_records, total_diff_qty, total_diff_value
-- >>> Bu sualın cavabındakı ANBAR bundan sonrakı bütün suallarda istifadə olunacaq.
--     Onun nömrəsini bir kənara yaz.
select 
    sc.warehouse_id,
    w.warehouse_name,
    count(sc.product_id) count_records,
    sum(sc.counted_qty-sc.system_qty) total_diff_qty,
    sum((sc.counted_qty-sc.system_qty)*p.unit_price) total_diff_value
from warehouse w join stock_count sc
on w.warehouse_id=sc.warehouse_id
join product p
on sc.product_id=p.product_id
group by sc.warehouse_id,w.warehouse_name
order by total_diff_value asc;

-- 3. Problemli anbarda itki nə vaxt başlayıb? Aylar üzrə itki miqdarını
--    və itki dəyərini göstər.
-- Cədvəllər: stock_count, product
-- Ay ölçüsü: count_date · Filtr: yalnız 2-ci sualda tapdığın anbar
-- Sıralama: ay artan.
-- Nəticə: month_text, diff_qty, diff_value
-- ƏLAVƏ (istəyə bağlı, bal artırır): sona bir sütun da əlavə et
--    running_loss = ayların kumulyativ (yığılan) itki dəyəri.
--    İpucu: sum(...) over (order by month_text)
select 
    to_char(sc.count_date,'YYYY-MM') month_text,
    sum(sc.system_qty-sc.counted_qty) diff_qty,
    sum((sc.system_qty-sc.counted_qty)*p.unit_price) diff_value,
    sum(sum((sc.system_qty-sc.counted_qty)*p.unit_price)) over (order by to_char(sc.count_date,'YYYY-MM')) running_loss
from stock_count sc join product p
on sc.product_id=p.product_id
where sc.warehouse_ıd=2
group by to_char(sc.count_date,'YYYY-MM')
order by month_text;


-- 4. Problemli anbarda hansı məhsullar itir? Məhsul üzrə əskik miqdarı və
--    dəyərini göstər. Məhsulun qiymətini və ÇƏKİSİNİ də sütunlara sal.
-- Cədvəllər: stock_count, product
-- Filtr: yalnız əskik çıxanlar (missing_qty > 0) - bunu having ilə filterlə.
-- Sıralama: itki dəyəri azalan.
-- Nəticə: product_id, product_name, unit_price, weight_kg, missing_qty, missing_value
-- >>> Sıranın yuxarısındakı 5 məhsulun ortaq cəhəti nədir? Bir cümlə ilə
--     şərh bölməsinə yaz. (Qiymətə və çəkiyə birlikdə bax.)
select
    p.product_id,
    p.product_name,
    p.unit_price,
    p.weight_kg,
    sum(sc.system_qty-sc.counted_qty) missing_qty,
    sum((sc.system_qty-sc.counted_qty)*p.unit_price) missing_value
from stock_count sc join product p
on sc.product_ıd=p.product_id
where sc.warehouse_id=2
group by p.product_id,
p.product_name,
p.unit_price,
p.weight_kg
having sum(sc.system_qty-sc.counted_qty)>0
order by missing_value desc;
-- en cox itki yaradan ilk 5 mehsul  qiymeti yuksek ve cekisi az olan mehsullardir,
--dasinmasi asan olsada itki deyeri daha coxdur.

-- 5. Sistemdə malı "silmək" üçün ADJUSTMENT hərəkəti istifadə olunur.
--    Bütün anbarlar üzrə hansı işçi neçə ADJUSTMENT edib, ümumi miqdar
--    və ümumi pul dəyəri nə qədərdir?
-- Cədvəllər: inventory_movement, employee, product, warehouse
-- Filtr: movement_type = 'ADJUSTMENT'
-- Sıralama: pul dəyəri artan (ən böyük mənfi yuxarıda).
-- Nəticə: employee_id, full_name, warehouse_name, adjustment_count,
--         total_adjusted_qty, total_adjusted_value
-- >>> Burada bir işçi qalan hamıdan kəskin fərqlənir. Onun employee_id-si
--     bundan sonra "ŞÜBHƏLİ №1"dir. Nömrəsini yaz. --employee_id =204 Rövşən Nəbiyev
select 
    e.employee_id,
    e.first_name || ' ' || e.last_name full_name,
    w.warehouse_name,
    count(*) adjustment_count,
    sum(im.quantity) total_adjusted_qty,
    round(sum(im.quantity*p.unit_price),2) total_adjusted_value
from inventory_movement im join employee e
on im.employee_id=e.employee_id
join product p 
on im.product_id=p.product_id
join warehouse w
on im.warehouse_id=w.warehouse_id
where im.movement_type='ADJUSTMENT'
group by e.employee_id,
e.first_name || ' ' || e.last_name,
w.warehouse_name
order by total_adjusted_value;



-- 6. Hər ADJUSTMENT hərəkətinin edildiyi gün həmin işçinin növbəsi nə idi?
--    İşçi və növbə tipi üzrə hərəkət sayını göstər.
-- Cədvəllər: inventory_movement, employee, work_shift
-- Birləşdirmə: work_shift ilə HƏM employee_id, HƏM DƏ tarix üzrə birləşdirin
--              (on s.employee_id = m.employee_id and s.shift_date = m.movement_date)
-- Qeyd: həmin gün işçinin ümumiyyətlə növbəsi yoxdursa 'NOVBESIZ' yazılsın
--       (left join + nvl).
-- Nəticə: employee_id, full_name, shift_type, adjustment_count
-- >>> ŞÜBHƏLİ №1-in düzəlişləri əsasən hansı növbədə edilib?--gece novbesinde edib 
select 
    e.employee_id,
    e.first_name || ' ' || e.last_name full_name,
    nvl(ws.shift_type,'NOVBESIZ') shift_type,
    count(*) adjustment_count
from inventory_movement im left join employee e
on im.employee_id=e.employee_id
left join work_shift ws
on im.employee_id=ws.employee_id and im.movement_date=ws.shift_date
where im.movement_type='ADJUSTMENT'
group by e.employee_id,
e.first_name || ' ' || e.last_name,
ws.shift_type
order by adjustment_count desc;



-- 7. İndi 6-cı sualdakı 'NOVBESIZ' sətirlərin arxasında nə olduğuna bax:
--    hansı ADJUSTMENT hərəkətləri işçinin ÜMUMİYYƏTLƏ növbədə OLMADIĞI
--    gün edilib? Yəni adam işdə deyildi, amma sistemə giriş olub.
-- Cədvəllər: inventory_movement, employee, product, work_shift
-- Həll: not exists
-- Sıralama: tarix artan.
-- Nəticə: movement_id, employee_id, full_name, movement_date, product_name, quantity
-- >>> Bu, hesabatın ən güclü sübutudur. Neçə sətirdir və kimə aiddir? 
select 
    movement_id,
    employee_id,
    (select first_name || ' ' || last_name from employee e where e.employee_id=im.employee_id) full_name,
    movement_date,
    (select product_name from product p where p.product_id=im.product_id) product_name,
    quantity
from inventory_movement im
where movement_type='ADJUSTMENT' and
not exists ( select 1 from work_shift ws where im.employee_id=ws.employee_id and im.movement_date=ws.shift_date)
order by im.movement_date asc;

select
    im.movement_id,
    e.employee_id,
    e.first_name || ' ' || e.last_name full_name,
    im.movement_date,
    p.product_name,
    im.quantity
from inventory_movement im join employee e
on im.employee_id=e.employee_id
join product p
on p.product_id=im.product_id
where im.movement_type='ADJUSTMENT' and
not exists ( select 1 from work_shift ws where im.employee_id=ws.employee_id and im.movement_date=ws.shift_date)
order by im.movement_date asc;
--3 setir ve Rovsen Nebiyev


-- 8. ŞÜBHƏLİ №1-in bütün ADJUSTMENT hərəkətlərini xronoloji sırala və hər
--    hərəkət üçün ƏVVƏLKİ hərəkətdən neçə gün keçdiyini hesabla.
-- Cədvəllər: inventory_movement, product
-- Filtr: movement_type = 'ADJUSTMENT' və employee_id = ŞÜBHƏLİ №1
-- İpucu: lag(movement_date) over (order by movement_date)
--        Oracle-da iki tarixi çıxsan nəticə gün sayı olur.
-- Nəticə: movement_id, movement_date, product_name, quantity, prev_date, days_since_prev
-- >>> Aralıqlara bax: təsadüfi görünür, yoxsa qrafik üzrə?
select 
    im.movement_id, 
    im.movement_date, 
    p.product_name, 
    im.quantity,
    lag(im.movement_date) over (order by im.movement_date) prev_date,
    im.movement_date-lag(im.movement_date) over (order by im.movement_date) days_since_prev
from inventory_movement im left join product p
on im.product_id=p.product_id
where im.movement_type='ADJUSTMENT' and im.employee_id=204
order by im.movement_date asc;

-- 9. Geri qaytarma səbəbləri üzrə ümumi mənzərə: hər səbəb kodu üzrə
--    müraciət sayı və ümumi geri ödəniş məbləği.
-- Cədvəllər: return_request
-- Sıralama: müraciət sayı azalan.
-- Nəticə: reason_code, request_count, total_refund
-- >>> Sağlam onlayn mağazada "mal çatmadı" iddiası bütün qaytarmaların
--     5-10%-i olur. Burada nə qədərdir? Öz-özünə hesabla və şərh yaz.
-- ƏLAVƏ (istəyə bağlı): sonuncu sütun kimi pct_of_all əlavə et —
--    hər səbəbin ümumi say içindəki faizi.
select 
    reason_code,
    count(*) request_count,
    sum(refund_amount) total_refund,
    round(count(*)*100.0/sum(count(*)) over (),2) pct_of_all
from return_request
group by reason_code
order by request_count desc;

--"mal çatmadı" 45.88% normadan xeyli yuksekdir.kuryer sirketi ile bagli problemler var,
--catdirilma prosesinde gecikme ve ya itkiler movcuddur,sifaris statusu sehv qeyd edilib,catdirilmalar tesdiqlenmeyib ve s

-- 10. Kuryerlər üzrə: neçə sifariş çatdırıb, həmin sifarişlərdən neçəsi
--     üçün 'NOT_RECEIVED' iddiası verilib və bu neçə faizdir?
-- Cədvəllər: delivery, employee, return_request
-- Birləşdirmə: return_request-i left join ilə qoşun (iddiası olmayan
--              çatdırılmalar da sayılmalıdır).
-- DİQQƏT: bir sifarişə birdən çox qaytarma düşə bilər - çatdırılma sayını
--         count(distinct d.order_id) ilə hesablayın, yoxsa faiz şişəcək.
-- Filtr: ən azı 10 çatdırılma etmiş kuryerlər (having).
-- Sıralama: faiz azalan.
-- Nəticə: courier_id, full_name, delivered_count, not_received_count, not_received_pct
-- >>> Burada da bir nəfər qalan hamıdan kəskin fərqlənir.
--     Onun employee_id-si "ŞÜBHƏLİ №2"dir. Nömrəsini yaz. 
select
    d.courıer_ıd,
    e.first_name || ' ' || e.last_name full_name,
    count(distinct d.order_id) delivered_count,
    count(distinct case
          when rr.reason_code='NOT_RECEIVED' then d.order_id
          end) not_received_count,
    round(count(distinct case
          when rr.reason_code='NOT_RECEIVED' then d.order_id
          end)*100.0/count(distinct d.order_id),2) not_received_pct
from delivery d join employee e
on d.courier_id=e.employee_id
left join return_request rr
on d.order_id=rr.order_id
group by d.courıer_ıd,e.first_name || ' ' || e.last_name
having count(distinct d.order_id)>=10
order by not_received_pct desc;
 --employee_id=206-li ceyhun semedov

-- 11. Məntiq yoxlaması: geri qaytarma TƏSDİQLƏNİBSƏ (APPROVED), mal fiziki
--     olaraq anbara qayıtmalıdır - yəni həmin sifariş üçün 'RETURN_IN'
--     hərəkəti olmalıdır (inventory_movement.reference_order_id sütunu).
--     Təsdiqlənib, amma anbara HEÇ NƏ qayıtmayan halları tap və səbəb kodu
--     üzrə qrupla.
-- Cədvəllər: return_request, inventory_movement
-- Həll: not exists
-- Nəticə: reason_code, request_count, total_loss
-- >>> Hansı səbəb kodunda mal demək olar heç vaxt geri gəlmir? Niyə? 
select
    reason_code,
    count(*) request_count,
    round(sum(refund_amount),2)  total_loss
from return_request rr 
where rr.return_status = 'APPROVED' and not exists (select 1 from inventory_movement im where rr.order_id=im.reference_order_id
and im.movement_type= 'RETURN_IN')
group by reason_code 
order by request_count desc;
--not_received de geri gelmir.esas problem mehsulun musteriye catmamasi ile baglidir


-- 12. Bu təsdiqləri kim verib? Hər işçi üzrə təsdiqlədiyi müraciət sayı,
--     müraciətdən təsdiqə qədər ORTA gün sayı və bunların içində neçəsinin
--     'NOT_RECEIVED' olduğu.
-- Cədvəllər: return_request, employee
-- Filtr: return_status = 'APPROVED'
-- Orta gün: avg(approve_date - request_date)
-- Sıralama: orta gün sayı artan.
-- Nəticə: employee_id, full_name, approved_count, avg_approve_days, not_received_count
-- >>> Normal təsdiq müddəti neçə gündür? Kim fərqlənir?
select 
    e.employee_id,
    e.first_name || ' ' || e.last_name full_name,
    count(*) approved_count,
    round(avg(rr.approve_date-rr.request_date),2) avg_approve_days,
    count(case
           when rr.reason_code='NOT_RECEIVED' then rr.approved_by
           end) not_received_count
from return_request rr join employee e
on rr.approved_by=e.employee_id
where rr.return_status = 'APPROVED'
group by e.employee_id,e.first_name || ' ' || e.last_name
order by avg_approve_days;
-- normali 3 gundur,ferqlenen ise aygundur, daha tez tesdiq verir ve 35i not receiveddir


-- 13. Təsdiqlənmiş 'NOT_RECEIVED' iddialarını müştəri üzrə qrupla:
--     hansı müştəri neçə dəfə iddia edib və şirkətə nə qədər başa gəlib?
-- Cədvəllər: return_request, orders, customer
-- Filtr: reason_code = 'NOT_RECEIVED' və return_status = 'APPROVED'
--        və ən azı 2 iddia (having)
-- Sıralama: məbləğ azalan.
-- Nəticə: customer_id, full_name, city, register_date, claim_count, total_refund
-- >>> Neçə nəfər çıxdı? Soyadlarına, şəhərlərinə və customer_id-lərinə diqqətlə bax. 5 nefer
select 
    c.customer_id,
    c.first_name || ' ' || c.last_name full_name,
    c.city,
    c.register_date,
    count(*) claim_count,
    round(sum(rr.refund_amount),2) total_refund
from return_request rr join orders o
on rr.order_id=o.order_id
join customer c 
on c.customer_id=o.customer_id
where rr.reason_code='NOT_RECEIVED' and return_status = 'APPROVED'
group by c.customer_id,
c.first_name || ' ' || c.last_name,
c.city,
c.register_date
having count(*) >= 2
order by total_refund desc;
 
-- 14. 13-cü sualdakı müştərilərin sifarişlərini kim çatdırıb?
--     Müştəri və kuryer üzrə sifariş sayını göstər.
-- Cədvəllər: orders, delivery, employee, customer
-- Filtr: yalnız 13-cü sualda tapdığın müştərilər (customer_id in (...))
-- Sıralama: customer_id artan.
-- Nəticə: customer_id, full_name, courier_id, courier_name, order_count
-- >>> Həmin anbarda 3 kuryer işləyir. Sifarişlər onların arasında necə bölünüb?
--     Bu, təsadüf ola bilərmi? Bir cümlə ilə şərh yaz.
select 
    c.customer_id, 
    c.first_name || ' ' || c.last_name full_name, 
    d.courier_id, 
    e.first_name || ' ' || e.last_name courier_name,
    count(*) order_count
from orders o join delivery d
on o.order_id=d.order_id
join employee e
on d.courier_id=e.employee_id
join customer c
on c.customer_id=o.customer_id
where c.customer_id in (select 
    c.customer_id
    from return_request rr join orders o
    on rr.order_id=o.order_id
    join customer c 
    on c.customer_id=o.customer_id
    where rr.reason_code='NOT_RECEIVED' and return_status = 'APPROVED'
    group by c.customer_id
    having count(*) >= 2) and e.warehouse_id=2
group by c.customer_id, 
c.first_name || ' ' || c.last_name, 
d.courier_id, 
e.first_name || ' ' || e.last_name
order by c.customer_id asc;

-- 15. Ziddiyyəti rəqəmlə göstər: delivery_status = 'DELIVERED' (kuryer
--     "təhvil verdim" deyib), amma müştəri "mal əlimə çatmadı" deyib və
--     bu iddia TƏSDİQLƏNİB. Kuryerlər üzrə say və məbləğ.
-- Cədvəllər: return_request, delivery, employee
-- Sıralama: məbləğ azalan.
-- Nəticə: courier_id, full_name, contradiction_count, total_loss
select
    e.employee_id as courier_id,
    e.first_name || ' ' || e.last_name full_name,
    count(distinct d.order_id) contradiction_count,
    round(sum(rr.refund_amount),2) total_loss
from delivery d join employee e 
on d.courier_id=e.employee_id 
join return_request rr 
on d.order_id=rr.order_id
where d.delivery_status = 'DELIVERED' and rr.reason_code='NOT_RECEIVED' and rr.return_status='APPROVED'
group by e.employee_id,
e.first_name || ' ' || e.last_name
order by total_loss desc;


-- 16. Şübhəli müştərilərin qeydiyyat tarixlərinə bax: onları qeydiyyat
--     tarixinə görə sırala və hər birinin ƏVVƏLKİNDƏN neçə gün sonra
--     qeydiyyatdan keçdiyini hesabla.
-- Cədvəllər: customer
-- Əhatə: 13-cü sualda tapdığın müştərilər
-- İpucu: lag(register_date) over (order by register_date)
-- Nəticə: customer_id, full_name, register_date, days_after_previous
-- >>> Nəticə təsadüfə oxşayırmı?-xeyr
select
    customer_id,
    first_name || ' ' || last_name full_name,
    register_date,
    register_date-lag(register_date) over (order by register_date) days_after_previous
from customer
where customer_id in (select 
    c.customer_id
    from return_request rr join orders o
    on rr.order_id=o.order_id
    join customer c 
    on c.customer_id=o.customer_id
    where rr.reason_code='NOT_RECEIVED' and return_status = 'APPROVED'
    group by c.customer_id
    having count(*) >= 2)
order by register_date asc;

    

-- 17. Şirkətin ümumi zərərini iki kanal üzrə hesabla və bir nəticə
--     dəstində birləşdir (union all):
--       kanal 1 - 'ANBAR_DUZELISI'  : ŞÜBHƏLİ №1-in ADJUSTMENT hərəkətləri
--                                     (inventory_movement + product)
--       kanal 2 - 'SAXTA_QAYTARMA'  : ŞÜBHƏLİ №2-nin çatdırdığı sifarişlər
--                                     üzrə təsdiqlənmiş NOT_RECEIVED məbləği
--                                     (return_request + delivery)
-- Nəticə: channel_name, loss_amount
-- >>> İki rəqəmi topla - direktora deyəcəyin məbləğ budur.
select 
'ANBAR_DUZELISI' as channel_name, 
round(sum(-im.quantity * p.unit_price),2)  loss_amount
from inventory_movement im join product p
on im.product_id=p.product_id
where im.movement_type='ADJUSTMENT'  and im.employee_id=204
 
union all
 
select 
'SAXTA_QAYTARMA' as channel_name,
round(sum(rr.refund_amount),2)  loss_amount
from return_request rr join delivery d
on rr.order_id=d.order_id
where d.courier_id=206 and rr.reason_code='NOT_RECEIVED' and rr.return_status = 'APPROVED';


--  YEKUN HESABAT (bunu SQL şərhi kimi faylın sonuna yaz)

--  Direktora 4 sualın cavabını yaz. Hər cavabın yanında HANSI SUALIN
--  nəticəsinə əsaslandığını göstər (məsələn: "sual 5 və 7-yə əsasən").
--
--  A) Anbar itkisinə görə kim məsuliyyət daşıyır? Sübut nədir?
--itkiye gore employee_id=204 olan Rovsen Nebiyev mesuliyyet dasiyir.Task 5,6 ve 7-ye esasen goruruk ki,
--en cox silme emeliyyati eden odur ve bunu gece novbesinde ve is gunu olmadigi halda edib.
--  B) Geri qaytarma sxemində kim iştirak edir? Neçə nəfərlik qrupdur?
--catdirildi deye gosteren kuryer-ceyhun -sual 14e esasen 
--tesdiqliyib meblegi qaytaran-aygun-sual 12e esasen
--saxta hesabli musteri
--  C) Sxem TEXNİKİ olaraq necə işləyir? (3-4 cümlə, addım-addım)
--ilk once saxta hesabla musteri sifaris edir.daha sonra kuryer mehsulu tehvil verdiyini gosterir sistemde.
--sonrada hemin saxta hesab mehsulun eline catmadigini deyir.
--ve operator da lazimi yoxlamani aparmadan qisa muddetde tesdibleyib,odenisi geri qaytarir.
--  D) Şirkətin ümumi zərəri neçə manatdır?
--Umumi zerer=48305 sual 17ye esasen






