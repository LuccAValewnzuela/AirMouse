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

    def test_default_sensitivity_is_4000(self):
        default_service = MovementProcessor()
        self.assertEqual(default_service.sensitivity, 4000)

    def test_sensitivity_can_be_updated(self):
        self.service.sensitivity = 2000
        dx_pixel, dy_pixel = self.service.process(0.1, 0.1)
        self.assertEqual(dx_pixel, 200)
        self.assertEqual(dy_pixel, 200)

if __name__ == "__main__":
    unittest.main()