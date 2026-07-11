"""
burnysc2 参考脚本：读取并打印开局单位

这是方案 B（外部 API），与方案 A（galaxy 内 DumpStartUnits）互为补充。

限制：
  - burnysc2 的 run_game 会自己启动 SC2.exe，无法直接加载本项目的 mod 依赖链
    (CoreRuntime + CommanderBridge + CommanderUnits_*)。
  - 若要连接 launch-7vs1-coop-test.ps1 启动的游戏，需让 SC2 启动时带
    -listen 127.0.0.1 -port 8765 参数，然后用 Observer 模式连入。
  - 此脚本作为 API 参考，展示 burnysc2 读取单位的能力。

依赖：pip install burnysc2
"""

from sc2 import maps
from sc2.bot_ai import BotAI
from sc2.data import Race, Difficulty
from sc2.main import run_game
from sc2.player import Bot, Computer


class DumpStartUnitsBot(BotAI):
    async def on_start(self):
        print("=" * 60)
        print(f"DumpStartUnits - on_start (player {self.player_id}, race {self.race})")
        print("=" * 60)

        print(f"Minerals: {self.minerals}, Gas: {self.vespene}")
        print(f"Supply: {self.supply_used}/{self.supply_cap}")

        # 我方单位（按类型分组打印）
        print(f"\n[My Units] total={self.units.amount}")
        for ut in self.units.type_ids:
            group = self.units.of_type({ut})
            sample = group.first
            print(f"  {ut.name:30s} x{group.amount}  pos={sample.position}")

        # 我方建筑
        print(f"\n[My Structures] total={self.structures.amount}")
        for st in self.structures.type_ids:
            group = self.structures.of_type({st})
            print(f"  {st.name:30s} x{group.amount}")

        # 敌方单位（仅视野内）
        if self.enemy_units:
            print(f"\n[Enemy Units] visible={self.enemy_units.amount}")
            for ut in self.enemy_units.type_ids:
                print(f"  {ut.name:30s} x{self.enemy_units.of_type({ut}).amount}")

        if self.enemy_structures:
            print(f"\n[Enemy Structures] visible={self.enemy_structures.amount}")
            for st in self.enemy_structures.type_ids:
                print(f"  {st.name:30s} x{self.enemy_structures.of_type({st}).amount}")

        print("=" * 60)

        # 只看开局单位的话可以直接退出
        # await self.client.leave()

    async def on_step(self, iteration: int):
        # 不做任何操作，让游戏自然结束
        pass


if __name__ == "__main__":
    # 修改为你的 SC2 地图名（需在 SC2/Maps 目录下）
    map_name = "Babylon LE"

    result = run_game(
        maps.get(map_name),
        [
            Bot(Race.Protoss, DumpStartUnitsBot()),
            Computer(Race.Random, Difficulty.Medium),
        ],
        realtime=False,
    )
    print(f"Game result: {result}")
