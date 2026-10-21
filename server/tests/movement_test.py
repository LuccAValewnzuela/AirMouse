import unittest
from server.movement.movement import MovementProcessor

class MovementTest(unittest.TestCase):

    def setUp(self, sensitivity=800):
        self.service = MovementProcessor(sensitivity)
        self.sensitivity = sensitivity

    def test_movement_processor(self):
        dx, dy = 0.12, -0.03
        dx_pixel, dy_pixel = self.service.process(dx, dy)
        self.assertEqual(dx_pixel, dx*self.sensitivity)
        self.assertEqual(dy_pixel, dy*self.sensitivity)

if __name__ == "__main__":
    unittest.main()