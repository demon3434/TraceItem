import io
import os
import random
from datetime import datetime, timezone
from pathlib import Path
from PIL import Image, ImageDraw
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password
from app.db.init_db import init_db
from app.db.session import SessionLocal, engine
from app.models.attachment import Attachment
from app.models.backup import BackupRecord
from app.models.item import Category, Item, Tag
from app.models.space import House, Room
from app.models.user import User
from app.services.backup_service import create_manual_tar_backup
from app.services.category_service import seed_user_default_categories


def generate_mock_image(title: str, subtitle: str, bg_color: tuple, text_color: tuple) -> tuple[str, str, int]:
    """生成带有高品质多巴胺配色的实景物品示意图及 300px 缩略图"""
    now = datetime.now()
    year_str = now.strftime("%Y")
    month_str = now.strftime("%m")
    unique_id = os.urandom(8).hex()

    rel_path = f"images/{year_str}/{month_str}/img_{unique_id}.jpg"
    abs_path = settings.MEDIA_DIR / rel_path
    abs_path.parent.mkdir(parents=True, exist_ok=True)

    thumb_rel = f"thumbnails/images/{year_str}/{month_str}/img_{unique_id}_thumb.jpg"
    thumb_abs = settings.MEDIA_DIR / thumb_rel
    thumb_abs.parent.mkdir(parents=True, exist_ok=True)

    w, h = 800, 600
    img = Image.new("RGB", (w, h), color=bg_color)
    draw = ImageDraw.Draw(img)

    draw.rounded_rectangle([24, 24, w - 24, h - 24], radius=24, outline=(255, 255, 255, 80), width=3)
    draw.rounded_rectangle([48, 48, w - 48, h - 48], radius=20, fill=(255, 255, 255, 40))

    draw.text((w // 2 - 120, h // 2 - 40), f"[ {title} ]", fill=text_color)
    draw.text((w // 2 - 100, h // 2 + 10), subtitle, fill=text_color)

    img.save(abs_path, format="JPEG", quality=85)
    file_size = os.path.getsize(abs_path)

    thumb = img.resize((300, 225), Image.Resampling.BILINEAR)
    thumb.save(thumb_abs, format="JPEG", quality=75)

    return rel_path, thumb_rel, file_size


def reset_database():
    """彻底重置数据库所有表和 FTS5 虚拟索引"""
    print(">>> 0. 正在清空旧数据与表结构...")
    from app.db.base import Base

    # 关闭 WAL 锁与事务并清理已有表
    with engine.connect() as conn:
        conn.execute(text("PRAGMA foreign_keys = OFF;"))
        for table in reversed(Base.metadata.sorted_tables):
            conn.execute(text(f"DROP TABLE IF EXISTS {table.name};"))
        conn.execute(text("DROP TABLE IF EXISTS items_fts;"))
        conn.execute(text("PRAGMA foreign_keys = ON;"))
        conn.commit()

    init_db()
    print("✓ 数据库表结构与 FTS5 索引重置完毕！")


def seed():
    reset_database()
    db: Session = SessionLocal()

    try:
        # 1. 创建系统管理员与普通用户账号 (账号独立，不赋予生硬家庭成员角色)
        users_data = [
            ("admin", "admin123", "系统管理员", "admin"),
            ("bob", "123456", "鲍勃", "user"),
            ("alice", "123456", "爱丽丝", "user"),
            ("charlie", "123456", "查理", "user"),
        ]
        user_map = {}
        for uname, pwd, nick, role in users_data:
            u = db.query(User).filter(User.username == uname).first()
            if not u:
                u = User(
                    username=uname,
                    password_hash=hash_password(pwd),
                    nickname=nick,
                    role=role,
                    is_active=True,
                )
                db.add(u)
            else:
                u.nickname = nick
                u.role = role
                u.password_hash = hash_password(pwd)
            db.commit()
            db.refresh(u)
            user_map[uname] = u

            if role != "admin":
                # 普通用户注入 14 套全场景分类模板；系统管理员不产生任何私有数据
                seed_user_default_categories(db, u.id)
                print(f"  + 已就绪用户: {nick} ({uname})，并预设 14 套全场景分类")
            else:
                print(f"  + 已就绪系统管理员: {nick} ({uname})，专职全局运维与审计，不产生任何物品/空间数据")

        alice = user_map["alice"]
        bob = user_map["bob"]
        admin = user_map["admin"]

        # 2. 为 Alice (妈妈) 创建房屋与多功能房间
        h_alice = House(user_id=alice.id, name="阳光城自己家", icon="🏠", sort_order=1)
        db.add(h_alice)
        h_alice_lake = House(user_id=alice.id, name="湖畔度假屋", icon="🏡", sort_order=2)
        db.add(h_alice_lake)
        db.commit()
        db.refresh(h_alice)
        db.refresh(h_alice_lake)

        rooms_alice_cfg = [
            ("大客厅", "🛋️", 1),
            ("主卧衣帽间", "🛏️", 2),
            ("查理秘密基地", "🧸", 3),
            ("开放式厨房", "🍳", 4),
            ("医药收纳柜", "💊", 5),
            ("阳光书房", "📚", 6),
            ("阳台生活区", "🌿", 7),
        ]
        alice_rooms = {}
        for rname, ricon, rsort in rooms_alice_cfg:
            r = Room(user_id=alice.id, house_id=h_alice.id, name=rname, icon=ricon, sort_order=rsort)
            db.add(r)
            db.commit()
            db.refresh(r)
            alice_rooms[rname] = r

        # 湖畔度假屋房间
        r_lake_terrace = Room(user_id=alice.id, house_id=h_alice_lake.id, name="休闲露台", icon="🍷", sort_order=1)
        r_lake_camp = Room(user_id=alice.id, house_id=h_alice_lake.id, name="露营装备库", icon="⛺", sort_order=2)
        db.add_all([r_lake_terrace, r_lake_camp])
        db.commit()
        db.refresh(r_lake_camp)

        # 为 Bob (爸爸) 创建老家空间 (系统管理员 admin 不产生任何房屋数据)
        h_bob = House(user_id=bob.id, name="老家自建房", icon="🛖", sort_order=1)
        db.add(h_bob)
        db.commit()
        db.refresh(h_bob)
        r_bob_tools = Room(user_id=bob.id, house_id=h_bob.id, name="车库五金房", icon="🧰", sort_order=1)
        db.add(r_bob_tools)
        db.commit()
        db.refresh(r_bob_tools)

        # 获取 Alice 拥有的 14 套分类映射
        alice_cats = {c.name: c for c in db.query(Category).filter(Category.user_id == alice.id).all()}

        # 3. 涵盖全部 14 种分类的丰富日常物品数据集
        items_dataset = [
            # 1. 💊 常备药品
            {
                "user": alice, "house": h_alice, "room": alice_rooms["医药收纳柜"],
                "cat": "常备药品", "name": "布洛芬缓释胶囊", "brand": "中美史克芬必得", "qty": 2,
                "loc": "医药箱上层红色药盒内", "desc": "成人退烧止痛备用，保质期至2027年10月",
                "tags": ["常备", "应急", "退烧"], "img": ("IBUPROFEN", "20 Capsules / Box", (254, 243, 199), (180, 83, 9))
            },
            {
                "user": alice, "house": h_alice, "room": alice_rooms["医药收纳柜"],
                "cat": "常备药品", "name": "医用无菌纱布与碘伏棉签", "brand": "海氏海诺", "qty": 5,
                "loc": "医药箱底层左侧抽屉", "desc": "外伤清创消毒备用，查理摔倒时使用",
                "tags": ["应急", "儿童护理"], "img": ("FIRST AID GAUZE", "Sterile Cotton Swab", (236, 253, 245), (4, 120, 87))
            },
            # 2. 📑 证件票据
            {
                "user": alice, "house": h_alice, "room": alice_rooms["主卧衣帽间"],
                "cat": "证件票据", "name": "全家户口簿与不动产权证书", "brand": "政务颁发", "qty": 3,
                "loc": "衣柜深处指纹密码保险箱第2格", "desc": "阳光城房屋不动产权证、全家户口簿原件",
                "tags": ["绝密", "重要证件", "全家公用"], "img": ("PROPERTY DEED", "Household Register & Deeds", (254, 226, 226), (185, 28, 28))
            },
            {
                "user": alice, "house": h_alice, "room": alice_rooms["主卧衣帽间"],
                "cat": "证件票据", "name": "全家护照与港澳通行证", "brand": "出入境管理局", "qty": 4,
                "loc": "保险箱蓝色证件收纳袋内", "desc": "一家三口因私护照，有效期至2032年",
                "tags": ["出境常用", "重要证件"], "img": ("PASSPORTS", "Family Travel Documents", (238, 242, 255), (67, 56, 202))
            },
            # 3. 🔌 数码配件
            {
                "user": alice, "house": h_alice, "room": alice_rooms["大客厅"],
                "cat": "数码配件", "name": "大疆 Osmo Pocket 3 口袋相机", "brand": "DJI", "qty": 1,
                "loc": "电视柜下方深灰色数码收纳包", "desc": "家庭出游记录主力设备，内含续航手柄与麦克风",
                "tags": ["贵重", "数码摄影", "出差常用"], "img": ("DJI POCKET 3", "Creator Combo Set", (241, 245, 249), (15, 23, 42))
            },
            {
                "user": alice, "house": h_alice, "room": alice_rooms["阳光书房"],
                "cat": "数码配件", "name": "闪极 100W 氮化镓多口快充头", "brand": "SHARGE", "qty": 2,
                "loc": "书桌右侧理线抽屉内", "desc": "支持笔记本与手机双路同时快充",
                "tags": ["数码配件", "快充", "书房"], "img": ("SHARGE 100W", "GaN Fast Charger", (254, 249, 195), (161, 98, 7))
            },
            # 4. 🧰 五金工具
            {
                "user": alice, "house": h_alice, "room": alice_rooms["阳台生活区"],
                "cat": "五金工具", "name": "世达 66 件多功能棘轮螺丝刀组", "brand": "SATA", "qty": 1,
                "loc": "阳台家政柜最下层工具盒", "desc": "精密数码与家用螺丝批头齐全",
                "tags": ["工具", "五金维修", "公用应急"], "img": ("SATA TOOLBOX", "66-Piece Ratchet Set", (224, 231, 255), (67, 56, 202))
            },
            # 5. 🧸 儿童玩具
            {
                "user": alice, "house": h_alice, "room": alice_rooms["查理秘密基地"],
                "cat": "儿童玩具", "name": "乐高机械组保时捷911", "brand": "LEGO Technic", "qty": 1,
                "loc": "白色收纳柜第3层亚克力防尘罩内", "desc": "查理6岁生日礼物，包含说明书和备用件",
                "tags": ["贵重", "儿童玩具", "积木"], "img": ("LEGO TECHNIC", "Porsche 911 RSR 42096", (255, 237, 213), (194, 65, 12))
            },
            {
                "user": alice, "house": h_alice, "room": alice_rooms["查理秘密基地"],
                "cat": "儿童玩具", "name": "磁力片百变摩天轮积木套装", "brand": "Magformers", "qty": 1,
                "loc": "地毯旁黄色大收纳筐", "desc": "118 片全磁力组件，拼装机械与建筑",
                "tags": ["儿童玩具", "益智"], "img": ("MAGFORMERS", "Magnetic Building Tiles", (254, 205, 211), (225, 29, 72))
            },
            # 6. ✏️ 办公文具
            {
                "user": alice, "house": h_alice, "room": alice_rooms["阳光书房"],
                "cat": "办公文具", "name": "辉柏嘉 48 色水溶性彩色铅笔", "brand": "Faber-Castell", "qty": 1,
                "loc": "书桌笔架旁铁盒", "desc": "查理画画与日常手绘专用",
                "tags": ["文具", "手绘"], "img": ("COLOR PENCILS", "Faber-Castell 48 Colors", (254, 240, 138), (161, 98, 7))
            },
            # 7. 🍳 厨房用品
            {
                "user": alice, "house": h_alice, "room": alice_rooms["开放式厨房"],
                "cat": "厨房用品", "name": "酷彩 24cm 经典圆形珐琅铸铁锅", "brand": "Le Creuset", "qty": 1,
                "loc": "燃气灶下方拉篮中层", "desc": "法式樱桃红，煲汤炖肉专用",
                "tags": ["厨房", "锅具"], "img": ("LE CREUSET", "Enameled Cast Iron Pot", (254, 202, 202), (220, 38, 38))
            },
            # 8. 🍵 食品干货
            {
                "user": alice, "house": h_alice, "room": alice_rooms["开放式厨房"],
                "cat": "食品干货", "name": "武夷山特级大红袍茶叶礼盒", "brand": "正山堂", "qty": 2,
                "loc": "厨房中岛台左侧茶道柜", "desc": "中秋走亲赠礼与待客好茶",
                "tags": ["茶叶", "待客", "食品"], "img": ("DA HONG PAO", "Wuyi Rock Tea Gift Box", (254, 243, 199), (146, 64, 14))
            },
            # 9. 🧼 日用清洁
            {
                "user": alice, "house": h_alice, "room": alice_rooms["主卧衣帽间"],
                "cat": "日用清洁", "name": "戴森 Supersonic 高速吹风机", "brand": "Dyson", "qty": 1,
                "loc": "梳妆台右侧软木吸盘挂架", "desc": "含防飞翘风嘴与顺滑风嘴",
                "tags": ["个护清洁", "电器"], "img": ("DYSON HAIR DRYER", "Supersonic HD15", (243, 232, 255), (126, 34, 206))
            },
            # 10. 👔 服饰鞋帽
            {
                "user": alice, "house": h_alice, "room": alice_rooms["主卧衣帽间"],
                "cat": "服饰鞋帽", "name": "始祖鸟 Beta LT 户外防水冲锋衣", "brand": "Arc'teryx", "qty": 1,
                "loc": "衣帽间中岛悬挂区第1位", "desc": "GORE-TEX 面料，雨雪季及登山出行必备",
                "tags": ["服装", "户外", "保暖"], "img": ("ARCTERYX BETA", "GORE-TEX Jacket", (204, 251, 241), (13, 148, 136))
            },
            # 11. 💄 美妆个护
            {
                "user": alice, "house": h_alice, "room": alice_rooms["主卧衣帽间"],
                "cat": "美妆个护", "name": "雅诗兰黛第七代小棕瓶修护精华", "brand": "Estee Lauder", "qty": 2,
                "loc": "梳妆台亚克力收纳旋转架", "desc": "100ml 免税店双支装备用",
                "tags": ["护肤", "美妆"], "img": ("ADVANCED NIGHT", "Estee Lauder Serum", (254, 242, 242), (153, 27, 27))
            },
            # 12. ⛺ 运动户外
            {
                "user": alice, "house": h_alice_lake, "room": r_lake_camp,
                "cat": "运动户外", "name": "挪客牧场金字塔户外大帐篷", "brand": "Naturehike", "qty": 1,
                "loc": "度假屋装备库第1排置物架", "desc": "可容纳4-6人，含防雨顶棚与铝合金地钉",
                "tags": ["露营", "户外", "周末"], "img": ("CAMPING TENT", "Naturehike Glamping Tent", (220, 252, 231), (22, 101, 52))
            },
            # 13. 🛋️ 家居家纺
            {
                "user": alice, "house": h_alice, "room": alice_rooms["大客厅"],
                "cat": "家居家纺", "name": "恐龙蛋多巴胺懒人沙发羽绒靠垫", "brand": "造作新家", "qty": 2,
                "loc": "大客厅落地窗阳台拐角", "desc": "高回弹环保粒子填充，暖橙色多巴胺面料",
                "tags": ["家具", "软装", "客厅"], "img": ("LAZY SOFA BEANBAG", "Cozy Ergonomic Cushion", (255, 237, 213), (194, 65, 12))
            },
            # 14. 📦 闲置收藏
            {
                "user": alice, "house": h_alice, "room": alice_rooms["阳光书房"],
                "cat": "闲置收藏", "name": "万代 RG 独角兽高达最终决战拼装模型", "brand": "BANDAI", "qty": 1,
                "loc": "书房玻璃展示柜顶部", "desc": "爸爸与查理耗时三天合力拼装完成，带发光支架",
                "tags": ["手办", "模型", "收藏"], "img": ("RG UNICORN GUNDAM", "Bandai Gunpla Special", (241, 245, 249), (51, 65, 85))
            },
            # 鲍勃的老家自建房五金物品
            {
                "user": bob, "house": h_bob, "room": r_bob_tools,
                "cat": None, "name": "博世 12V 锂电无刷冲击钻套装", "brand": "BOSCH", "qty": 1,
                "loc": "车库左侧蓝色金属挂板最下层", "desc": "修家具打孔专用，配套有混凝土钻头与瓷砖钻头",
                "tags": ["工具", "五金维修", "公用应急"], "img": ("BOSCH 12V DRILL", "Brushless Cordless Kit", (224, 231, 255), (67, 56, 202))
            },
        ]

        # 4. 写入物品、标签与实景多媒体附件
        for it in items_dataset:
            rel_img, thumb_img, fsize = generate_mock_image(
                title=it["img"][0],
                subtitle=it["img"][1],
                bg_color=it["img"][2],
                text_color=it["img"][3],
            )

            tags = []
            for tname in it["tags"]:
                t = db.query(Tag).filter(Tag.name == tname).first()
                if not t:
                    t = Tag(name=tname)
                    db.add(t)
                    db.flush()
                tags.append(t)

            cat_entity = alice_cats.get(it["cat"]) if it["cat"] else None

            new_item = Item(
                user_id=it["user"].id,
                house_id=it["house"].id,
                room_id=it["room"].id,
                category_id=cat_entity.id if cat_entity else None,
                name=it["name"],
                brand=it["brand"],
                quantity=it["qty"],
                location_detail=it["loc"],
                description=it["desc"],
                tags=tags,
            )
            db.add(new_item)
            db.flush()

            attachment = Attachment(
                item_id=new_item.id,
                media_type="image",
                file_path=rel_img,
                thumbnail_path=thumb_img,
                file_size=fsize,
                duration_seconds=0,
                width=800,
                height=600,
                display_order=1,
            )
            db.add(attachment)
            db.commit()
            print(f"  + 已生成测试物品: [{it['cat'] or '未分类'}] {new_item.name} ({it['user'].nickname})")

        # 5. 生成一份初始的 Admin TAR 纯打包备份
        print(">>> 正在生成系统初始纯 TAR 备份包...")
        rec = create_manual_tar_backup(db)
        print(f"✓ 初始 TAR 备份已就绪: {rec.filename} ({rec.file_size_display})")

        print(">>> 🎉 一家人的账号、房屋及涵盖全部 14 种分类的丰富日常物品重新初始化完毕！")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
